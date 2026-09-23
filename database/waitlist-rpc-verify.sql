-- READ ONLY. Run as the database administrator; no email values are returned.
SELECT relrowsecurity AS rls_enabled FROM pg_class WHERE oid = 'public.waitlist'::regclass;
SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'waitlist' ORDER BY ordinal_position;

SELECT role_name,
  has_table_privilege(role_name, 'public.waitlist', 'SELECT') AS table_select,
  has_table_privilege(role_name, 'public.waitlist', 'INSERT') AS table_insert,
  has_table_privilege(role_name, 'public.waitlist', 'UPDATE') AS table_update,
  has_table_privilege(role_name, 'public.waitlist', 'DELETE') AS table_delete,
  has_any_column_privilege(role_name, 'public.waitlist', 'SELECT') AS column_select,
  has_any_column_privilege(role_name, 'public.waitlist', 'INSERT') AS column_insert,
  has_any_column_privilege(role_name, 'public.waitlist', 'UPDATE') AS column_update,
  has_function_privilege(role_name, 'public.join_waitlist(text,text)', 'EXECUTE') AS rpc_execute
FROM (VALUES ('anon'), ('authenticated'), ('machonce_waitlist_writer')) AS roles(role_name);

SELECT p.prosecdef AS security_definer, p.proconfig AS settings,
  pg_get_userbyid(p.proowner) AS function_owner, p.proacl AS function_acl
FROM pg_proc p WHERE p.oid = 'public.join_waitlist(text,text)'::regprocedure;
SELECT policyname, roles, cmd, qual, with_check FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'waitlist';
-- Review any other publicly executable function that references the waitlist.
SELECT p.oid::regprocedure AS other_function, p.prosecdef AS security_definer
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname <> 'join_waitlist'
  AND p.prosrc ILIKE '%waitlist%' AND has_function_privilege('anon', p.oid, 'EXECUTE');
SELECT rolname, rolsuper, rolcanlogin, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls
FROM pg_roles WHERE rolname = 'machonce_waitlist_writer';
SELECT pg_get_userbyid(member) AS member_role FROM pg_auth_members
WHERE roleid = 'machonce_waitlist_writer'::regrole;

-- Count inconsistencies without exposing addresses.
SELECT count(*) FILTER (WHERE email IS DISTINCT FROM lower(btrim(email))) AS unnormalized_rows,
  count(*) FILTER (WHERE consent_version IS NULL OR btrim(consent_version) = '') AS missing_consent_rows,
  count(*) FILTER (WHERE id IS NULL OR created_at IS NULL) AS missing_generated_fields
FROM public.waitlist;
