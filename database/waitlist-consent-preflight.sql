-- READ ONLY. Run in the Supabase SQL Editor as the project owner.
-- Do not copy real email addresses into logs, tickets or public reports.
SELECT id, email, created_at
FROM public.waitlist
ORDER BY created_at;

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'waitlist'
ORDER BY ordinal_position;

SELECT relrowsecurity AS rls_enabled
FROM pg_class
WHERE oid = 'public.waitlist'::regclass;

SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public' AND table_name = 'waitlist'
  AND grantee IN ('anon', 'authenticated', 'PUBLIC')
ORDER BY grantee, privilege_type;

SELECT policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'waitlist';
