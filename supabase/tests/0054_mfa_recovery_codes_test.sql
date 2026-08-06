-- 0054_mfa_recovery_codes_test.sql
-- Recovery codes: a locked-out staff member's self-service way back in.
-- The load-bearing test is #3 — an aal1 caller must not be able to mint codes,
-- or two-factor is defeated by password alone.

BEGIN;
SET search_path TO extensions, public;

SELECT plan(12);

INSERT INTO auth.users (id) VALUES
  ('00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000e2');

-- 1-2. The table is unreachable directly: RLS is on with zero policies AND
-- every privilege is revoked, so even the owner cannot read their own hashes.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';

SELECT throws_ok(
  'SELECT * FROM mfa_recovery_codes',
  '42501', NULL,
  'authenticated cannot SELECT mfa_recovery_codes directly');

SELECT throws_ok(
  $$INSERT INTO mfa_recovery_codes (user_id, code_hash)
    VALUES ('00000000-0000-0000-0000-0000000000e1', 'x')$$,
  '42501', NULL,
  'authenticated cannot INSERT mfa_recovery_codes directly');

-- 3. THE BYPASS. An aal1 session must not be able to mint codes: it could
-- redeem one immediately and defeat two-factor with the password alone.
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal1"}';
SELECT throws_ok(
  'SELECT generate_mfa_recovery_codes()',
  'P0001', NULL,
  'an aal1 session cannot generate recovery codes');

-- 4. A missing aal claim fails closed too.
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1"}';
SELECT throws_ok(
  'SELECT generate_mfa_recovery_codes()',
  'P0001', NULL,
  'a missing aal claim fails closed, not open');

-- 5-6. An aal2 session gets ten codes in the documented shape.
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';
SELECT is(
  array_length(generate_mfa_recovery_codes(), 1), 10,
  'an aal2 session gets ten codes');

SELECT ok(
  (SELECT bool_and(c ~ '^[0-9A-F]{5}-[0-9A-F]{5}-[0-9A-F]{5}-[0-9A-F]{5}$')
     FROM unnest(generate_mfa_recovery_codes()) AS c),
  'every code is four groups of five uppercase hex');

-- 7. Regenerating replaces the previous set rather than adding to it.
-- This count is a direct table read to inspect internal state, not an
-- application-level access — and the migration deliberately revokes ALL
-- table privileges from `authenticated` (see tests 1-2), so the check must
-- run outside that role. RESET ROLE returns to the session's original
-- (superuser) role, which bypasses the REVOKE.
--
-- It IS re-set to `authenticated` immediately after, with the matching jwt
-- claims: assertions 8, 9 and 11 below call `redeem_mfa_recovery_code`, and
-- that function is only reachable via `GRANT EXECUTE ... TO authenticated`.
-- Leaving the role reset to superuser would bypass that grant check entirely,
-- so those assertions would keep passing even if the GRANT were later dropped
-- or mis-scoped — a coverage gap on exactly the security surface this
-- feature exists to test. Re-setting the role after each introspection read
-- keeps the redeem-path assertions honest.
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'),
  10,
  'regenerating replaces the previous set');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';

-- 8-11. Redemption. Mint a known set and redeem one of them.
-- If CREATE TEMP TABLE is refused for the `authenticated` role, add
-- `RESET ROLE;` before it and re-set the role plus the jwt claims after — the
-- codes only need capturing, not capturing under that role.
CREATE TEMP TABLE issued AS
  SELECT unnest(generate_mfa_recovery_codes()) AS code;

SELECT ok(
  redeem_mfa_recovery_code((SELECT code FROM issued LIMIT 1)),
  'a valid code is accepted');

SELECT ok(
  NOT redeem_mfa_recovery_code((SELECT code FROM issued LIMIT 1)),
  'the same code is refused the second time');

-- Redemption clears the rest: once two-factor is off they are dangling
-- credentials. One burned row remains as the audit trail.
-- Same reasoning as assertion 7: this is a direct table read, so it needs
-- superuser to bypass the REVOKE; role is re-set to `authenticated` again
-- right after, with user e2's claims this time, so assertion 11 (below)
-- still proves the GRANT on `redeem_mfa_recovery_code` for that user.
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'),
  1,
  'redemption clears the remaining codes, keeping the burned one');

-- 11-12. Another user's code is not accepted — and, crucially, a failed
-- cross-account attempt does not silently burn or consume it.
--
-- By this point every code in `issued` except the burned one has been
-- DELETEd (assertion 8's redemption cleanup wipes the rest of e1's set), so
-- attempting an `issued` row here would fail simply because no such row
-- exists anywhere — a stripped `WHERE user_id = v_user` predicate in
-- `redeem_mfa_recovery_code` would still make this pass. Mint a *live* set
-- for e1 first, so the only possible reason for refusal is the ownership
-- filter.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';
CREATE TEMP TABLE live_e1 AS
  SELECT unnest(generate_mfa_recovery_codes()) AS code;

-- NB: SELECT, not PERFORM — PERFORM is plpgsql-only and is a syntax error in a
-- plain SQL script like this one.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e2","aal":"aal2"}';
SELECT generate_mfa_recovery_codes();
SELECT ok(
  NOT redeem_mfa_recovery_code((SELECT code FROM live_e1 LIMIT 1)),
  'another user''s live code is refused');

-- The code e2 was refused must still work for its actual owner — proving
-- e2's attempt neither burned nor otherwise consumed it. A naive "return
-- false but burn anyway" implementation would fail this.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';
SELECT ok(
  redeem_mfa_recovery_code((SELECT code FROM live_e1 LIMIT 1)),
  'the code e2 was refused still redeems for its actual owner');

SELECT * FROM finish();
ROLLBACK;
