-- Run once as the database administrator after inspecting the current schema.
-- Only the email default changes; no rows, constraints or permissions change.
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE public.waitlist IN ACCESS EXCLUSIVE MODE;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'waitlist'
      AND column_name = 'email' AND data_type = 'text' AND is_nullable = 'NO'
      AND column_default = $expected$''::text$expected$
  ) THEN
    RAISE EXCEPTION 'Expected email text NOT NULL with empty-string default. Stop and inspect the schema; this migration may already be applied.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attname = 'email'
    WHERE c.conrelid = 'public.waitlist'::regclass AND c.contype = 'u'
      AND c.convalidated AND c.conkey = ARRAY[a.attnum]
  ) THEN
    RAISE EXCEPTION 'Expected an existing UNIQUE constraint on email. Stop and inspect the schema.';
  END IF;
END;
$migration$;

ALTER TABLE public.waitlist ALTER COLUMN email DROP DEFAULT;

COMMIT;

-- Read-only post-check: email must have column_default NULL; consent is unchanged.
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'waitlist'
  AND column_name IN ('email', 'consent_version')
ORDER BY ordinal_position;
