-- 0054_mfa_recovery_codes_test.sql
-- Recovery codes: a locked-out staff member's self-service way back in.
-- The load-bearing test is #3 — an aal1 caller must not be able to mint codes,
-- or two-factor is defeated by password alone.

BEGIN;
SET search_path TO extensions, public;

SELECT plan(27);

INSERT INTO auth.users (id) VALUES
  ('00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000e2');

-- 1-4. The table is unreachable directly: RLS is on with zero policies AND
-- every privilege is revoked, so even the owner cannot read their own hashes.
-- The spec calls out SELECT, INSERT, UPDATE and DELETE explicitly; a blanket
-- REVOKE ALL covers all four, but each gets its own assertion so a future
-- narrowing of that REVOKE is caught here rather than assumed.
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

SELECT throws_ok(
  $$UPDATE mfa_recovery_codes SET used_at = now()
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'$$,
  '42501', NULL,
  'authenticated cannot UPDATE mfa_recovery_codes directly');

SELECT throws_ok(
  $$DELETE FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'$$,
  '42501', NULL,
  'authenticated cannot DELETE mfa_recovery_codes directly');

-- 5. THE BYPASS. An aal1 session must not be able to mint codes: it could
-- redeem one immediately and defeat two-factor with the password alone.
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal1"}';
SELECT throws_ok(
  'SELECT generate_mfa_recovery_codes()',
  'P0001', NULL,
  'an aal1 session cannot generate recovery codes');

-- 6. A missing aal claim fails closed too.
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1"}';
SELECT throws_ok(
  'SELECT generate_mfa_recovery_codes()',
  'P0001', NULL,
  'a missing aal claim fails closed, not open');

-- 7-8. An aal2 session gets ten codes in the documented shape.
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';
SELECT is(
  array_length(generate_mfa_recovery_codes(), 1), 10,
  'an aal2 session gets ten codes');

SELECT ok(
  (SELECT bool_and(c ~ '^[0-9A-F]{5}-[0-9A-F]{5}-[0-9A-F]{5}-[0-9A-F]{5}$')
     FROM unnest(generate_mfa_recovery_codes()) AS c),
  'every code is four groups of five uppercase hex');

-- 9. Regenerating replaces the previous set rather than adding to it.
-- This count is a direct table read to inspect internal state, not an
-- application-level access — and the migration deliberately revokes ALL
-- table privileges from `authenticated` (see tests 1-4), so the check must
-- run outside that role. RESET ROLE returns to the session's original
-- (superuser) role, which bypasses the REVOKE.
--
-- It IS re-set to `authenticated` immediately after, with the matching jwt
-- claims: the redemption assertions below call `redeem_mfa_recovery_code`,
-- and that function is only reachable via `GRANT EXECUTE ... TO
-- authenticated`. Leaving the role reset to superuser would bypass that
-- grant check entirely, so those assertions would keep passing even if the
-- GRANT were later dropped or mis-scoped — a coverage gap on exactly the
-- security surface this feature exists to test. Re-setting the role after
-- each introspection read keeps the redeem-path assertions honest.
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'),
  10,
  'regenerating replaces the previous set');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';

-- 10-13. Redemption. Mint a known set and redeem one of them.
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

-- Redemption alone must NOT touch the sibling codes: that deletion used to
-- happen inside `redeem_mfa_recovery_code` itself, which meant a failed
-- factor deletion in the Edge Function (after the burn had already
-- committed) left the user with zero usable codes — every one of the
-- remaining nine had already been wiped by the redeem call that "succeeded".
-- The delete now lives in `clear_mfa_recovery_codes`, called by the Edge
-- Function only once the factor deletion has actually gone through. So right
-- after a redeem: nine unused rows plus the one just-burned row = ten.
-- Same reasoning as assertion 9: this is a direct table read, so it needs
-- superuser to bypass the REVOKE; role is re-set to `authenticated`
-- immediately after.
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'),
  10,
  'redeeming one code leaves the other nine untouched');

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';

-- `clear_mfa_recovery_codes` is the piece that used to live inside the
-- redeem RPC: it deletes the remaining unused codes, keeping the burned row
-- as the audit trail. Unlike the other two functions here, it is NOT on the
-- `authenticated` surface at all — it is a destructive primitive with no aal
-- gate (it has to run on the aal1 redeem path by design), so the grant is
-- the entire security property. Assert the grant boundary directly, not
-- just the happy path.
-- Asserted with has_function_privilege rather than throws_ok on purpose.
-- Calling a function you lack EXECUTE on, from inside pgTAP's throws_ok,
-- CRASHES the Postgres backend on this version ("server closed the connection
-- unexpectedly") — reproduced in isolation, and it takes the rest of the file
-- with it. The catalog check asserts the same property more directly, needs no
-- role switching, and cannot be confused with a runtime failure.
--
-- `anon` is the one that actually bit. Supabase's default privileges grant
-- EXECUTE on every new public function to anon AND authenticated, and revoking
-- from `public` touches neither. A REVOKE naming only `public, authenticated`
-- therefore left anon holding EXECUTE — an UNAUTHENTICATED way to wipe any
-- user's codes over PostgREST using the anon key that ships inside the client.
-- Verified exploitable against a live database before it was corrected.
RESET ROLE;
SELECT ok(
  NOT has_function_privilege('authenticated',
                             'clear_mfa_recovery_codes(uuid)', 'EXECUTE'),
  'authenticated cannot EXECUTE clear_mfa_recovery_codes');

SELECT ok(
  NOT has_function_privilege('anon',
                             'clear_mfa_recovery_codes(uuid)', 'EXECUTE'),
  'anon cannot EXECUTE clear_mfa_recovery_codes');

SELECT ok(
  has_function_privilege('service_role',
                         'clear_mfa_recovery_codes(uuid)', 'EXECUTE'),
  'service_role can EXECUTE clear_mfa_recovery_codes');

-- Only service_role can call it — this is what the Edge Function's admin
-- client does, passing the userId it already verified from the caller's own
-- JWT, after it has confirmed the TOTP factor deletion actually succeeded.
SET LOCAL ROLE service_role;
SELECT clear_mfa_recovery_codes('00000000-0000-0000-0000-0000000000e1');
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'),
  1,
  'clear_mfa_recovery_codes removes the remaining codes, keeping the burned one');

-- 14-15. Another user's code is not accepted — and, crucially, a failed
-- cross-account attempt does not silently burn or consume it.
--
-- e1 has only the burned row left at this point (the assertion above cleared
-- the rest), so mint a fresh *live* set for e1 first, so the only possible
-- reason for refusal is the ownership filter, not "no such row anywhere".
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

-- 19-20. Clearing your OWN codes is gated on aal2, exactly like minting them.
-- An aal1 session (password known, authenticator not) destroying someone's
-- break-glass codes is a denial of their recovery path rather than a privilege
-- gain, but a password alone still should not be able to do it.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal1"}';
SELECT throws_ok(
  'SELECT clear_own_mfa_recovery_codes()',
  'P0001', NULL,
  'an aal1 session cannot clear its own recovery codes');

SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1"}';
SELECT throws_ok(
  'SELECT clear_own_mfa_recovery_codes()',
  'P0001', NULL,
  'a missing aal claim cannot clear its own codes either');

-- 21-22. The turn-off path itself. e1 clears its own live codes; the burned
-- row stays as the audit trail, and e2's set is untouched. That second half is
-- the property which makes this safe to put on the `authenticated` surface at
-- all: there is no user id for a caller to get wrong or to forge.
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e1","aal":"aal2"}';
SELECT clear_own_mfa_recovery_codes();

RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'
      AND used_at IS NULL),
  0,
  'clear_own_mfa_recovery_codes removes the caller''s own live codes');

SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e2'
      AND used_at IS NULL),
  10,
  'clearing your own codes does not touch another user''s');

-- 23. The burned row survives, so the audit trail is not destroyed by a
-- turn-off. Asserted separately from #21 because "removed the live ones" and
-- "kept the used one" fail in different directions: a DELETE that dropped the
-- WHERE clause would still pass #18.
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'
      AND used_at IS NOT NULL),
  1,
  'clearing your own codes keeps the burned row as the audit trail');

-- 24-25. The grant split that makes the two clear functions different.
-- `clear_mfa_recovery_codes(uuid)` is service_role-only because a
-- caller-supplied user id is safe only while nobody but service_role can pass
-- one. This one takes NO argument, so it can reach exactly the caller's rows —
-- which is what makes it safe to grant to `authenticated`. If a future change
-- ever gives this an argument, these two assertions are the ones that should
-- stop it.
--
-- Catalog check rather than throws_ok, for the reason documented above: calling
-- a function you lack EXECUTE on crashes the backend on this Postgres version
-- and takes the rest of the file with it.
SELECT ok(
  has_function_privilege('authenticated',
                         'clear_own_mfa_recovery_codes()', 'EXECUTE'),
  'authenticated can EXECUTE clear_own_mfa_recovery_codes');

SELECT ok(
  NOT has_function_privilege('anon',
                             'clear_own_mfa_recovery_codes()', 'EXECUTE'),
  'anon cannot EXECUTE clear_own_mfa_recovery_codes');

-- 26-27. It takes no arguments and never has. Both assertions exist to make a
-- future `clear_own_mfa_recovery_codes(uuid)` overload — which would reopen
-- exactly the cross-account hole the argument-less design avoids — a test
-- failure rather than a review catch.
SELECT is(
  (SELECT count(*)::int FROM pg_proc
    WHERE proname = 'clear_own_mfa_recovery_codes'),
  1,
  'there is exactly one clear_own_mfa_recovery_codes');

SELECT is(
  (SELECT pronargs::int FROM pg_proc
    WHERE proname = 'clear_own_mfa_recovery_codes'),
  0,
  'clear_own_mfa_recovery_codes takes no arguments');

SELECT * FROM finish();
ROLLBACK;
