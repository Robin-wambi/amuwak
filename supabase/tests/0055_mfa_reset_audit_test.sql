-- 0055_mfa_reset_audit_test.sql
-- Clearing someone's second factor deliberately weakens their account, so it
-- must leave a record. Managers may read that record; nobody else may, and no
-- client may write it.
BEGIN;
SET search_path TO extensions, public;

SELECT plan(4);

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

-- Nobody writes it from a client; only the service role (which bypasses RLS).
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-0000000000a1';
PREPARE client_insert AS
  INSERT INTO mfa_reset_audit (actor_staff_id, target_staff_id, factors_cleared)
  VALUES ('00000000-0000-0000-0000-0000000000a1',
          '00000000-0000-0000-0000-0000000000a3', 1);
SELECT throws_ok('client_insert', '42501',
  NULL, 'even a manager cannot forge an audit row');

PREPARE client_delete AS
  DELETE FROM mfa_reset_audit;
EXECUTE client_delete;
SELECT is(
  (SELECT count(*)::int FROM mfa_reset_audit), 1,
  'the log survives an attempted delete (RLS matches no rows)');

SELECT * FROM finish();
ROLLBACK;
