-- 0057_table_grants.sql
-- Until now no migration granted a table privilege to a client role. Table
-- access came from Supabase's default privileges — set by the vendor, absent
-- from this repository, pinned to no version. Supabase has since narrowed that
-- default from `arwdDxtm` to `Dxtm` for anon, authenticated and service_role,
-- so:
--
--   1. A database rebuilt from these migrations has no working client. The
--      customer app cannot read or insert an order. Disaster recovery, staging
--      and any fork are all affected.
--   2. `authenticated` holds TRUNCATE on every table, on old and new stacks
--      alike. TRUNCATE ignores row-level policies, so RLS does no work there.
--
-- The invariant, asserted generically in 0057_table_grants_test.sql: the verbs
-- a table grants `authenticated` equal the verbs its RLS policies name. A verb
-- with a policy and no grant is dead code; a grant with no policy is held back
-- by RLS alone, which is exactly how the TRUNCATE hole survived.
--
-- Revoke-then-grant rather than naming verbs to remove. `ALL` is seven
-- privileges and the leftovers are the dangerous ones — the lesson from 0056,
-- where `REVOKE INSERT, UPDATE, DELETE` would have left TRUNCATE behind.

-- === REVOKE (generated) ===
REVOKE ALL ON carts FROM anon, authenticated, service_role;
REVOKE ALL ON customers FROM anon, authenticated, service_role;
REVOKE ALL ON expenses FROM anon, authenticated, service_role;
REVOKE ALL ON issues FROM anon, authenticated, service_role;
REVOKE ALL ON mfa_recovery_codes FROM anon, authenticated, service_role;
REVOKE ALL ON mfa_reset_audit FROM anon, authenticated, service_role;
REVOKE ALL ON order_code_counters FROM anon, authenticated, service_role;
REVOKE ALL ON order_messages FROM anon, authenticated, service_role;
REVOKE ALL ON order_status_events FROM anon, authenticated, service_role;
REVOKE ALL ON orders FROM anon, authenticated, service_role;
REVOKE ALL ON pricing_catalog_items FROM anon, authenticated, service_role;
REVOKE ALL ON pricing_settings FROM anon, authenticated, service_role;
REVOKE ALL ON proof_events FROM anon, authenticated, service_role;
REVOKE ALL ON proof_photos FROM anon, authenticated, service_role;
REVOKE ALL ON shifts FROM anon, authenticated, service_role;
REVOKE ALL ON staff FROM anon, authenticated, service_role;
REVOKE ALL ON valid_transitions FROM anon, authenticated, service_role;

-- === GRANT to authenticated (generated) ===
GRANT DELETE, INSERT, SELECT, UPDATE ON carts TO authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON customers TO authenticated;
GRANT INSERT, SELECT, UPDATE ON expenses TO authenticated;
GRANT INSERT, SELECT ON issues TO authenticated;
-- mfa_reset_audit_manager_read (0056) is a SELECT-only policy, gating the
-- audit log to active managers; no INSERT/UPDATE/DELETE policy exists for
-- authenticated, matching 0056's own comment that only the service-role
-- client (reset-staff-mfa) writes it.
GRANT SELECT ON mfa_reset_audit TO authenticated;
-- order_messages generates as INSERT, SELECT, UPDATE — the UPDATE comes from
-- order_messages_mark_read (0046), a row-level policy that authorizes
-- updating a visible message but says nothing about which COLUMN. Verbatim
-- table-wide UPDATE here would re-grant exactly what 0046 revoked on purpose
-- (REVOKE UPDATE ON order_messages FROM anon, authenticated) to stop a
-- customer rewriting a staff reply's body or forging its sender, so this
-- table's UPDATE is column-scoped instead, matching 0046 exactly. (Verified,
-- not assumed: a table-wide GRANT plus a per-column REVOKE was tried and does
-- not narrow anything — a role holding the table-level privilege has it on
-- every column regardless of any column-level REVOKE; column grants only ever
-- ADD access a missing table-level privilege doesn't cover, never subtract
-- from one already held. See task-2-report.md for the CI runs that pinned
-- this down, and 0057_table_grants_test.sql's header for why assertion 1
-- accepts a column grant as equivalent to a table grant.)
--
-- The REVOKE ALL above DOES remove 0046's original column grant along with
-- everything else — table and column ACLs are separate catalogs, but ALL
-- covers both — so it must be re-granted explicitly here, not assumed to
-- survive.
GRANT INSERT, SELECT ON order_messages TO authenticated;
GRANT UPDATE (read_at) ON order_messages TO authenticated;
GRANT INSERT, SELECT ON order_status_events TO authenticated;
GRANT INSERT, SELECT, UPDATE ON orders TO authenticated;
GRANT INSERT, SELECT, UPDATE ON pricing_catalog_items TO authenticated;
GRANT SELECT, UPDATE ON pricing_settings TO authenticated;
GRANT INSERT, SELECT ON proof_events TO authenticated;
GRANT INSERT, SELECT ON proof_photos TO authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON shifts TO authenticated;
GRANT DELETE, INSERT, SELECT, UPDATE ON staff TO authenticated;
GRANT SELECT ON valid_transitions TO authenticated;

-- === GRANT to service_role (generated) ===
-- service_role bypasses RLS by design and its key never reaches a browser, so
-- its blast radius is already the whole database; excluding TRUNCATE simply
-- removes a verb nothing uses.
--
-- `mfa_recovery_codes` is deliberately absent. 0054 states the only way into
-- that table is its two SECURITY DEFINER functions, and both Edge Function call
-- sites go through them. A direct grant here would quietly falsify that.
--
-- `mfa_reset_audit` is deliberately present: reset-staff-mfa writes it with the
-- service-role client directly, not through a function.
GRANT SELECT, INSERT, UPDATE, DELETE ON carts TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON customers TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON expenses TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON issues TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON mfa_reset_audit TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_code_counters TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_messages TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_status_events TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON pricing_catalog_items TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON pricing_settings TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON proof_events TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON proof_photos TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON shifts TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON valid_transitions TO service_role;

-- === Future tables start closed ===
-- A new table now has zero client access until its own migration says
-- otherwise. Forgetting fails loudly in the db-tests job rather than quietly in
-- production.
--
-- `FOR ROLE postgres` only. Migrations run as postgres, which is not a member
-- of supabase_admin and cannot alter its defaults — so a table created as
-- supabase_admin (for example through the dashboard) still inherits the
-- permissive default. Create tables through migrations and this holds.
--
-- ON TABLES only. The default grants `authenticated` `w` on sequences and
-- `nextval()` accepts UPDATE or USAGE, so revoking sequence defaults would
-- break inserts that rely on a sequence default, for no security gain.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated, service_role;
