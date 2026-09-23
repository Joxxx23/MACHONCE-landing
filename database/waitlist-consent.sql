-- Run only after reviewing the preflight results and resolving legacy rows.
-- No row is deleted or backfilled by this migration; permissions stay unchanged.
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE public.waitlist IN ACCESS EXCLUSIVE MODE;

DO $migration$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.waitlist'::regclass) THEN
    RAISE EXCEPTION 'RLS must be enabled before applying this migration.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'waitlist'
      AND column_name = 'consent_version'
  ) THEN
    IF EXISTS (SELECT 1 FROM public.waitlist) THEN
      RAISE EXCEPTION 'Legacy waitlist rows exist. Review them first; never invent historical consent.';
    END IF;
    ALTER TABLE public.waitlist ADD COLUMN consent_version text;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'waitlist'
      AND column_name = 'consent_version' AND data_type <> 'text'
  ) THEN
    RAISE EXCEPTION 'Unexpected consent_version type. Review the existing schema.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.waitlist WHERE consent_version IS NULL OR btrim(consent_version) = '') THEN
    RAISE EXCEPTION 'Rows without recorded consent remain. Do not backfill a consent version.';
  END IF;
END;
$migration$;

-- No DEFAULT: older clients must not silently obtain a consent version.
ALTER TABLE public.waitlist ALTER COLUMN consent_version DROP DEFAULT;
ALTER TABLE public.waitlist ALTER COLUMN consent_version SET NOT NULL;
COMMENT ON COLUMN public.waitlist.consent_version IS
  'Explicitly accepted consent text version; see docs/consent-versions.md. Never backfill historical consent.';

NOTIFY pgrst, 'reload schema';
COMMIT;
