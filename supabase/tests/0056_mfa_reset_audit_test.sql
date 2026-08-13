-- 0056_mfa_reset_audit_test.sql
-- Clearing someone's second factor deliberately weakens their account, so it
-- must leave a record. Managers may read that record; nobody else may, and no
-- client may write it.
BEGIN;
SET search_path TO extensions, public;

SELECT plan(8);

INSERT INTO public.staff (id, username, display_name, role, active) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'mgr_a', 'Manager A', 'manager', true),
  ('00000000-0000-0000-0000-0000000000a3', 'drv_a', 'Driver A', 'driver', true);

INSERT INTO public.mfa_reset_audit
  (actor_staff_id, target_staff_id, factors_cleared) VALUES
  ('00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-0000000000a3', 1);

SET LOCAL ROLE authenticated;

-- A manager can read the log.
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-0000000000a1';
SELECT is(
  (SELECT count(*)::int FROM mfa_reset_audit), 1,
  'a manager reads the reset log');

-- A driver cannot — note this is the 0039 trap: auth_staff_role() would call
-- this driver a manager, so the policy must not use it.
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-0000000000a3';
SELECT is(
  (SELECT count(*)::int FROM mfa_reset_audit), 0,
  'a driver cannot read the reset log');

-- Nobody writes it from a client; only the service role (which bypasses both
-- RLS and the REVOKE). Every verb gets its own assertion rather than trusting
-- one to stand for the others.
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-0000000000a1';
PREPARE client_insert AS
  INSERT INTO mfa_reset_audit (actor_staff_id, target_staff_id, factors_cleared)
  VALUES ('00000000-0000-0000-0000-0000000000a1',
          '00000000-0000-0000-0000-0000000000a3', 1);
SELECT throws_ok('client_insert', '42501',
  NULL, 'even a manager cannot forge an audit row');

PREPARE client_update AS
  UPDATE mfa_reset_audit SET factors_cleared = 0;
SELECT throws_ok('client_update', '42501',
  NULL, 'even a manager cannot rewrite an audit row');

-- Before the REVOKE this deleted zero rows and returned quietly, because RLS
-- simply matched nothing. Now the privilege is gone, so it is refused outright.
PREPARE client_delete AS
  DELETE FROM mfa_reset_audit;
SELECT throws_ok('client_delete', '42501',
  NULL, 'even a manager cannot erase an audit row');

-- The one RLS could never have stopped: TRUNCATE does not consult policies, so
-- before the REVOKE this would have emptied the log for a signed-in manager.
-- Passed as SQL rather than PREPAREd like its siblings because TRUNCATE is a
-- utility statement and PREPARE takes only SELECT/INSERT/UPDATE/DELETE.
SELECT throws_ok($$TRUNCATE mfa_reset_audit$$, '42501',
  NULL, 'even a manager cannot truncate the audit log');

-- The three above would still pass on RLS alone, so they cannot tell whether
-- the REVOKE is there. These two read the grants directly: delete the REVOKE
-- and only these fail, which is the point of having them.
SELECT table_privs_are('public', 'mfa_reset_audit', 'authenticated',
  ARRAY['SELECT'],
  'authenticated may only read the log, before RLS is even consulted');
SELECT table_privs_are('public', 'mfa_reset_audit', 'anon',
  ARRAY[]::text[],
  'anon holds no privilege on the log at all');

SELECT * FROM finish();
ROLLBACK;
