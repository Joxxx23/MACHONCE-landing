-- Run as postgres AFTER waitlist-rpc.sql. All synthetic fixtures are rolled back.
-- No existing rows are read into output or changed. No email is printed.
BEGIN;
DO $fixture$
BEGIN
  PERFORM set_config('machonce.qa_email', 'machonce-rpc-qa-' || gen_random_uuid()::text || '@example.com', true);
END;
$fixture$;

DO $check$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.waitlist'::regclass) THEN
    RAISE EXCEPTION 'FAIL: RLS is disabled';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE oid = 'public.join_waitlist(text,text)'::regprocedure
      AND prosecdef AND proowner = 'machonce_waitlist_writer'::regrole
      AND 'search_path=""' = ANY(proconfig)
  ) THEN
    RAISE EXCEPTION 'FAIL: function owner/security/search_path';
  END IF;
END;
$check$;

SET LOCAL ROLE anon;
DO $check$
DECLARE expected jsonb := '{"accepted":true}'; value text; command text;
BEGIN
  IF public.join_waitlist('  ' || upper(current_setting('machonce.qa_email')) || '  ', 'waitlist-v2-2026-09-18') <> expected
    OR public.join_waitlist(current_setting('machonce.qa_email'), 'waitlist-v2-2026-09-18') <> expected THEN
    RAISE EXCEPTION 'FAIL: new and duplicate acknowledgements differ or registration failed';
  END IF;
  FOREACH value IN ARRAY ARRAY[NULL, '', ' ', 'no-at', 'bad@example', 'two@@example.com', 'a b@example.com', repeat('a',255)||'@example.com'] LOOP
    IF public.join_waitlist(value, 'waitlist-v2-2026-09-18') <> '{"accepted":false}'::jsonb THEN
      RAISE EXCEPTION 'FAIL: invalid address accepted';
    END IF;
  END LOOP;
  FOREACH value IN ARRAY ARRAY[NULL, '', 'waitlist-v1-2026-09-17', 'unknown'] LOOP
    IF public.join_waitlist(current_setting('machonce.qa_email'), value) <> '{"accepted":false}'::jsonb THEN
      RAISE EXCEPTION 'FAIL: invalid consent version accepted';
    END IF;
  END LOOP;
  FOREACH command IN ARRAY ARRAY[
    'SELECT email FROM public.waitlist LIMIT 0',
    'INSERT INTO public.waitlist(email,consent_version) VALUES (current_setting(''machonce.qa_email''),''waitlist-v2-2026-09-18'')',
    'UPDATE public.waitlist SET email=email WHERE false',
    'DELETE FROM public.waitlist WHERE false'
  ] LOOP
    BEGIN
      EXECUTE command;
      RAISE EXCEPTION 'FAIL: a direct public table operation was allowed';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;
END;
$check$;
RESET ROLE;

DO $check$
DECLARE row_data public.waitlist%ROWTYPE;
BEGIN
  IF (SELECT count(*) FROM public.waitlist WHERE email = current_setting('machonce.qa_email')) <> 1 THEN
    RAISE EXCEPTION 'FAIL: normalized address does not have exactly one row';
  END IF;
  SELECT * INTO row_data FROM public.waitlist WHERE email = current_setting('machonce.qa_email');
  IF row_data.id IS NULL OR row_data.created_at IS DISTINCT FROM current_timestamp
    OR row_data.consent_version <> 'waitlist-v2-2026-09-18' THEN
    RAISE EXCEPTION 'FAIL: database defaults or recorded consent';
  END IF;
  IF has_table_privilege('authenticated','public.waitlist','SELECT,INSERT,UPDATE,DELETE')
    OR has_any_column_privilege('authenticated','public.waitlist','SELECT,INSERT,UPDATE')
    OR has_function_privilege('authenticated','public.join_waitlist(text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: authenticated role gained waitlist access';
  END IF;
END;
$check$;

-- Verify that an existing v1 fixture is not updated/renewed by a v2 duplicate.
INSERT INTO public.waitlist(email, consent_version, created_at)
VALUES ('legacy-' || current_setting('machonce.qa_email'), 'waitlist-v1-2026-09-17', '2026-09-17 00:00:00+00');
SET LOCAL ROLE anon;
DO $check$
BEGIN
  IF public.join_waitlist('legacy-' || current_setting('machonce.qa_email'), 'waitlist-v2-2026-09-18') <> '{"accepted":true}'::jsonb THEN
    RAISE EXCEPTION 'FAIL: legacy duplicate acknowledgement';
  END IF;
END;
$check$;
RESET ROLE;
DO $check$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.waitlist WHERE email = 'legacy-' || current_setting('machonce.qa_email')
    AND consent_version = 'waitlist-v1-2026-09-17' AND created_at = '2026-09-17 00:00:00+00') THEN
    RAISE EXCEPTION 'FAIL: historical consent was modified';
  END IF;
END;
$check$;

-- An unexpected constraint failure must return only a fixed failure object.
ALTER TABLE public.waitlist ADD CONSTRAINT machonce_qa_forced_error
  CHECK (email NOT LIKE 'forced-error-%') NOT VALID;
SET LOCAL ROLE anon;
DO $check$
BEGIN
  IF public.join_waitlist('forced-error-' || current_setting('machonce.qa_email'), 'waitlist-v2-2026-09-18') <> '{"accepted":false}'::jsonb THEN
    RAISE EXCEPTION 'FAIL: internal database failure acknowledgement';
  END IF;
END;
$check$;
RESET ROLE;
ROLLBACK;
SELECT 'PASS: RPC, normalization, uniqueness, consent/defaults, RLS, privileges and sanitized errors; fixtures rolled back' AS result;
