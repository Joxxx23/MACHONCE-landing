-- Run as postgres in the Supabase SQL Editor, after waitlist-consent.sql.
-- Atomic cutover: no rows are deleted, backfilled, updated or returned.
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE public.waitlist IN ACCESS EXCLUSIVE MODE;

DO $preflight$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Run this migration as the project database administrator (postgres).';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'waitlist'
      AND column_name = 'consent_version' AND data_type = 'text'
      AND is_nullable = 'NO' AND column_default IS NULL
  ) THEN
    RAISE EXCEPTION 'Apply waitlist-consent.sql after reviewing legacy rows first.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.waitlist
    WHERE email IS DISTINCT FROM lower(btrim(email)) OR btrim(consent_version) = ''
  ) THEN
    RAISE EXCEPTION 'Review existing normalization/consent data before migration; no automatic rewrite is safe.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c JOIN pg_attribute a
      ON a.attrelid = c.conrelid AND c.conkey = ARRAY[a.attnum]::smallint[]
    WHERE c.conrelid = 'public.waitlist'::regclass AND c.contype = 'u'
      AND a.attname = 'email' AND NOT c.condeferrable
  ) THEN
    RAISE EXCEPTION 'An immediate UNIQUE constraint on email is required.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'join_waitlist'
      AND p.oid <> COALESCE(to_regprocedure('public.join_waitlist(text,text)')::oid, 0)
  ) THEN
    RAISE EXCEPTION 'Review unexpected join_waitlist overloads before exposing this RPC.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'machonce_waitlist_writer') THEN
    CREATE ROLE machonce_waitlist_writer NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = 'machonce_waitlist_writer'
      AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls OR rolinherit)
  ) OR EXISTS (
    SELECT 1 FROM pg_auth_members WHERE member = 'machonce_waitlist_writer'::regrole
  ) THEN
    RAISE EXCEPTION 'The dedicated function owner must have no login, elevated attributes or inherited roles.';
  END IF;
END;
$preflight$;

ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.waitlist FROM PUBLIC, anon, authenticated, machonce_waitlist_writer;
-- Table-level REVOKE alone would leave separately granted column privileges intact.
DO $columns$
DECLARE column_list text;
BEGIN
  SELECT string_agg(quote_ident(attname), ', ') INTO column_list
  FROM pg_attribute WHERE attrelid = 'public.waitlist'::regclass AND attnum > 0 AND NOT attisdropped;
  EXECUTE format('REVOKE ALL PRIVILEGES (%s) ON public.waitlist FROM PUBLIC, anon, authenticated, machonce_waitlist_writer', column_list);
END;
$columns$;

GRANT USAGE ON SCHEMA public TO anon, machonce_waitlist_writer;
GRANT INSERT (email, consent_version), SELECT (email) ON public.waitlist TO machonce_waitlist_writer;
DROP POLICY IF EXISTS machonce_waitlist_rpc_insert ON public.waitlist;
CREATE POLICY machonce_waitlist_rpc_insert ON public.waitlist
  FOR INSERT TO machonce_waitlist_writer WITH CHECK (
    email = lower(btrim(email)) AND consent_version = 'waitlist-v2-2026-09-18'
  );
-- ON CONFLICT (email) requires SELECT visibility for the internal owner only.
DROP POLICY IF EXISTS machonce_waitlist_rpc_conflict ON public.waitlist;
CREATE POLICY machonce_waitlist_rpc_conflict ON public.waitlist
  FOR SELECT TO machonce_waitlist_writer USING (true);

-- Only the existing administrator may assume the dedicated owner for maintenance.
GRANT machonce_waitlist_writer TO postgres;
GRANT CREATE ON SCHEMA public TO machonce_waitlist_writer;
CREATE OR REPLACE FUNCTION public.join_waitlist(email text, consent_version text)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $function$
#variable_conflict use_column
DECLARE
  normalized_email text := pg_catalog.lower(pg_catalog.btrim(join_waitlist.email));
BEGIN
  IF normalized_email IS NULL OR pg_catalog.length(normalized_email) > 254
    OR normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    OR join_waitlist.consent_version IS DISTINCT FROM 'waitlist-v2-2026-09-18' THEN
    RETURN '{"accepted":false}'::jsonb;
  END IF;

  INSERT INTO public.waitlist (email, consent_version)
  VALUES (normalized_email, join_waitlist.consent_version)
  ON CONFLICT (email) DO NOTHING;

  RETURN '{"accepted":true}'::jsonb;
EXCEPTION
  -- Never echo SQLSTATE, SQLERRM, constraint names, row data or the email.
  WHEN query_canceled OR OTHERS THEN
    RETURN '{"accepted":false}'::jsonb;
END;
$function$;
ALTER FUNCTION public.join_waitlist(text, text) OWNER TO machonce_waitlist_writer;
REVOKE CREATE ON SCHEMA public FROM machonce_waitlist_writer;
REVOKE ALL ON FUNCTION public.join_waitlist(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.join_waitlist(text, text) TO anon;

DO $verify$
DECLARE public_role text;
BEGIN
  FOREACH public_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    IF has_table_privilege(public_role, 'public.waitlist', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
      OR has_any_column_privilege(public_role, 'public.waitlist', 'SELECT,INSERT,UPDATE,REFERENCES')
      OR pg_has_role(public_role, 'machonce_waitlist_writer', 'MEMBER') THEN
      RAISE EXCEPTION 'Public access remains through inherited privileges. Review roles; migration rolled back.';
    END IF;
  END LOOP;
END;
$verify$;

COMMENT ON FUNCTION public.join_waitlist(text, text) IS
  'MACHONCE registration: fixed acknowledgement for new/duplicate; no rows or existence flags returned.';
NOTIFY pgrst, 'reload schema';
COMMIT;
