-- 0057_table_grants_test.sql
-- The privilege layer and the policy layer must agree. A verb with a policy and
-- no grant is dead code; a grant with no policy is held back by RLS alone,
-- which is how `authenticated` kept TRUNCATE on every table for so long.
--
-- Deliberately generic. Naming tables here would mean a seventeenth table could
-- be added with no grants and no failure — the exact gap this file exists to
-- close.
--
-- "Grant" means table-level OR column-level. RLS gates rows, never columns, so
-- a policy that should only ever touch one column (0046_customer_rls.sql's
-- order_messages_mark_read: a customer may mark a staff reply read but must
-- never rewrite its body or forge its sender) cannot rely on the policy for
-- that — the column grant is the only thing enforcing it, on purpose,
-- REVOKEd at the table level and re-GRANTed on that one column. A table-only
-- check would demand a table-wide grant here and defeat the column scoping
-- that makes the restriction real, so a verb counts as granted if EITHER a
-- table-level or an at-least-one-column-level grant exists.
BEGIN;
SET search_path TO extensions, public;

SELECT plan(4);

-- 1. The invariant itself, in both directions. `is_empty` rather than a count,
-- because on failure it prints the offending (table, verb) rows and a count
-- prints "have 3 want 0".
SELECT is_empty($$
  WITH policy_verbs AS (
    SELECT tablename::text AS tbl,
           unnest(CASE WHEN cmd = 'ALL'
                       THEN ARRAY['SELECT','INSERT','UPDATE','DELETE']
                       ELSE ARRAY[cmd] END) AS verb
      FROM pg_policies
     WHERE schemaname = 'public'
  ),
  granted AS (
    SELECT c.relname::text AS tbl, v.verb
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) AS v(verb)
     WHERE n.nspname = 'public' AND c.relkind = 'r'
       AND (
         has_table_privilege('authenticated', c.oid, v.verb)
         OR EXISTS (
           SELECT 1 FROM pg_attribute a
            WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
              AND has_column_privilege('authenticated', c.oid, a.attnum, v.verb)
         )
       )
  )
  (SELECT tbl, verb, 'granted, no policy' AS problem FROM granted
    EXCEPT
   SELECT tbl, verb, 'granted, no policy' FROM policy_verbs)
  UNION ALL
  (SELECT tbl, verb, 'policy, no grant' AS problem FROM policy_verbs
    EXCEPT
   SELECT tbl, verb, 'policy, no grant' FROM granted)
$$, 'authenticated holds exactly the verbs its RLS policies name');

-- 2. anon reaches nothing. Every policy in this schema requires a signed-in
-- identity, so any anon privilege is dead weight waiting to matter.
SELECT is_empty($$
  SELECT c.relname::text AS tbl, v.verb
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE',
                            'TRUNCATE','REFERENCES','TRIGGER']) AS v(verb)
   WHERE n.nspname = 'public'
     AND c.relkind = 'r'
     AND has_table_privilege('anon', c.oid, v.verb)
$$, 'anon holds no privilege on any table in public');

-- 3. The one RLS can never gate. TRUNCATE does not consult policies, so a
-- client role holding it can empty a table outright.
SELECT is_empty($$
  SELECT c.relname::text AS tbl, r.rolname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN (VALUES ('anon'),('authenticated'),('service_role')) AS r(rolname)
   WHERE n.nspname = 'public'
     AND c.relkind = 'r'
     AND has_table_privilege(r.rolname, c.oid, 'TRUNCATE')
$$, 'no client role holds TRUNCATE anywhere in public');

-- 4. Future tables start closed. Scoped to grantor `postgres` because that is
-- the role migrations run as, and the only one this migration can alter.
SELECT is_empty($$
  SELECT defaclrole::regrole::text AS grantor, defaclacl::text AS acl
    FROM pg_default_acl
   WHERE defaclnamespace::regnamespace::text = 'public'
     AND defaclobjtype = 'r'
     AND defaclrole = 'postgres'::regrole
     AND EXISTS (
       SELECT 1 FROM unnest(defaclacl) a
        WHERE a::text ~ '^(anon|authenticated|service_role)='
     )
$$, 'tables created by postgres grant nothing to client roles by default');

SELECT * FROM finish();
ROLLBACK;
