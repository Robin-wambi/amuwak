# MFA recovery codes — design

Date: 2026-08-06
Branch: `feat/mfa-foundation` (PR #105)
Status: approved, ready for an implementation plan

## Problem

PR #105 ships optional TOTP two-factor for staff. Its own description names the
gap: Supabase has no native recovery codes, so a staff member who loses their
authenticator is locked out, and the escape hatch is operational — sign out, and
a manager unenrols the factor from the Supabase dashboard.

Later work on the same PR added self-service un-enrolment from Account, which
narrows the gap but does not close it. Anyone who can still *pass* the challenge
can now turn two-factor off themselves. Someone genuinely locked out is stopped
at the gate before Account exists, so they still need a manager.

This design closes it: a staff member who has lost their authenticator can get
back in on their own with a recovery code they were given at enrolment.

## The constraint that forces the shape

**A recovery code cannot produce an `aal2` session.** GoTrue mints `aal2` only
from a verified factor challenge; no custom RPC or Edge Function can issue that
claim. So "redeeming a recovery code" can only mean one thing that works:
delete the user's TOTP factor server-side, which drops `nextLevel` to `aal1`,
so the challenge stops appearing and they get in with their password.

The alternative — validating the code client-side and routing past the challenge
— is worthless. The JWT stays `aal1`, so once `aal2` RLS enforcement lands it
fails anyway, and until then it is a pure client-side bypass.

A consequence worth stating plainly: **redemption turns two-factor off.** The
user is told so, and the Account entry reads `Off` until they re-enrol.

## The security control this all rests on

The obvious implementation ships a complete bypass:

> Sign in with password → session is `aal1` → call "generate recovery codes" →
> receive 10 fresh plaintext codes → redeem one → factor deleted → two-factor
> defeated with the password alone.

So **`generate_mfa_recovery_codes()` must reject any caller whose session is not
already `aal2`**, checked in the function as `auth.jwt() ->> 'aal' = 'aal2'`.

Redemption does not need the same check: it requires knowing a code, and codes
are only ever shown to a session that was already at `aal2`.

This is the single most important line in the feature. It gets a pgTAP test
named for the bypass it prevents.

## Where each piece lives

Postgres owns the secrets. The Edge Function owns the factor deletion. That
split is forced by two verified facts:

- **No migration in this repo has ever written to an `auth.*` table** — they
  only read, via `auth.uid()` and FK references to `auth.users`. A
  `DELETE FROM auth.mfa_factors` would be a first, and is unsupported by
  Supabase: the `auth` schema belongs to GoTrue and may change under us.
- **A locked-out user cannot unenrol themselves.** GoTrue requires `aal2` to
  unenrol a *verified* factor — precisely what they cannot reach.

So factor deletion goes through the GoTrue admin API in an Edge Function holding
the service-role key, following the `invite-staff` precedent already in the repo
(`supabase/functions/invite-staff/index.ts`).

## Migration 0054

0053 is the latest migration; 0054 is the next free prefix. The
`migrations-lint` workflow rejects duplicate prefixes on every PR, so this must
not collide.

```sql
CREATE TABLE mfa_recovery_codes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash  text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  used_at    timestamptz
);

CREATE INDEX mfa_recovery_codes_unused_idx
  ON mfa_recovery_codes (user_id) WHERE used_at IS NULL;

ALTER TABLE mfa_recovery_codes ENABLE ROW LEVEL SECURITY;
-- Deliberately ZERO policies. RLS enabled with no policy denies everyone,
-- including the owner. Every access path is a SECURITY DEFINER function below.
REVOKE ALL ON mfa_recovery_codes FROM anon, authenticated;
```

Nobody ever reads their own hashes. The blanket `REVOKE` plus policy-less RLS
means the table is unreachable except through the two functions.

### Code format

`extensions.gen_random_bytes(10)` — 80 bits — rendered as uppercase hex and
grouped for transcription: `XXXXX-XXXXX-XXXXX-XXXXX` (deviates from the
Crockford base32 `XXXX-XXXX-XXXX-XXXX` sketched above; entropy is unchanged at
80 bits, hex was simpler to implement against `encode(..., 'hex')`). Ten codes
per user. Redemption normalises input by stripping non-alphanumerics and
upper-casing, so a user typing spaces, lowercase, or no dashes still succeeds.

Plaintext exists exactly once: in the return value of the generate call. It is
never stored, never logged, and never returned again.

### Hashing

bcrypt, `crypt(code, gen_salt('bf'))` from the `pgcrypto` extension already
enabled in `extensions` (migration 0001).

Verification cannot look up by hash — it fetches the caller's unused rows and
tests `crypt(p_code, code_hash) = code_hash` against each, at most ten bcrypt
operations on a rare path. That cost is irrelevant here, and it means a leaked
table is not one wordlist away from being useful. Doing the same work whether or
not a code matches also avoids handing out a timing signal.

### Functions

Both `SECURITY DEFINER`, `SET search_path = public`, with the house grant
pattern (`REVOKE EXECUTE FROM public; GRANT EXECUTE TO authenticated`).

`generate_mfa_recovery_codes() RETURNS text[]`
- Rejects a caller with no `auth.uid()`.
- **Rejects a caller whose `auth.jwt() ->> 'aal'` is not `aal2`** — the control
  described above. Written as `IS DISTINCT FROM 'aal2'` so a missing or null
  claim fails *closed*: nobody can mint codes, rather than everybody. (The
  access-token hook merges into `event->'claims'` rather than rebuilding it, so
  `aal` does survive to the minted token — but the check does not depend on
  that holding.)
- Deletes the caller's existing codes, inserts ten fresh hashes, returns the ten
  plaintexts.

`redeem_mfa_recovery_code(p_code text) RETURNS boolean`
- Normalises `p_code`, finds a matching unused row for `auth.uid()`.
- No match → `false`.
- Match → sets `used_at = now()` on that row and returns `true`. It does
  **not** touch the caller's other codes — see `clear_mfa_recovery_codes`
  below and the ordering note under "Redemption flow".
- The burn is a single atomic `UPDATE ... WHERE id = ... AND used_at IS NULL
  RETURNING id`, so concurrent redemptions of one code cannot both win.

`clear_mfa_recovery_codes() RETURNS void`
- Deletes the caller's remaining **unused** codes for `auth.uid()`, leaving
  any already-burned rows in place as the audit trail.
- Split out of `redeem_mfa_recovery_code` so the Edge Function can call it
  only after the TOTP factor deletion has actually succeeded, not
  unconditionally on every successful burn. Once two-factor is off, leftover
  codes are dangling credentials; re-enrolling issues a fresh set.

## Redemption flow

The Edge Function `redeem-recovery-code`:

1. Identifies the caller from their `Authorization` JWT. An `aal1` session is
   expected and fine — but it must be a real, password-authenticated session.
   There is no anonymous path: an attacker needs the password *and* a code.
2. Calls `redeem_mfa_recovery_code` **as the caller** (a client built with the
   user's token, not the service role) so `auth.uid()` resolves and no
   `user_id` is accepted from the request body — nothing to spoof.
3. On `true`, uses the service-role admin API to delete that user's verified
   MFA factors. Any failure here (list or delete) is reported as an error —
   including the case where the factor list comes back with no verified
   factor to delete, which is treated as failure rather than silent success.
4. Only once that deletion is confirmed does it call
   `clear_mfa_recovery_codes` **as the caller**, to remove the now-redundant
   remaining codes. A failure here is logged but not fatal — the user is
   already back in on their password alone.
5. Returns success. The client then calls `refreshSession()` —
   `getAuthenticatorAssuranceLevel` reads factors off the cached session user,
   so without a refresh the gate would not notice. `needsMfaChallengeProvider`
   recomputes to `false` and `AuthGate` moves on by itself, the same way it does
   after a successful challenge.

### Ordering: burn first, delete-siblings last (revised)

Burn-then-delete-factor is atomic and auditable, and is unchanged from the
original design: the RPC burns the code first, so concurrent redemptions of
one code cannot both win.

What changed: the original design had `redeem_mfa_recovery_code` delete the
caller's other nine codes in the same transaction as the burn, on the premise
that if the subsequent admin-API factor deletion then failed, the user "still
has nine left to retry." That premise was false against the implementation —
the RPC ran *before* the admin call, so by the time a factor-deletion failure
was possible, the other nine codes were already gone. Every retry the user
made after that failure read "not valid," having burned the deletion
transaction's row already. A user who hit that failure was left with zero
working codes — worse off than before the feature existed.

The fix splits sibling deletion into its own function,
`clear_mfa_recovery_codes`, called by the Edge Function only *after* the
factor deletion has actually succeeded (step 4 above). If the factor deletion
fails, the caller's other nine codes are simply never touched, and "try
another code" is now genuinely true.

The alternative — verify, delete, then burn — fails safe toward letting the user
in, but the gap between verify and burn means one code could be accepted twice
concurrently. Burn-first remains the choice for that reason; only the ordering
of the sibling-deletion step changed. The Edge Function logs a factor-deletion
failure loudly, since that is the case where a user is left stuck (with codes
intact) rather than locked out entirely.

## No rate-limit table

Eighty bits of entropy behind an endpoint that already requires a valid password
session. Brute force is not the threat, and an attempt counter would be
machinery guarding nothing. Supabase's platform rate limits still apply to the
Edge Function.

## Client

**Core** — a `RecoveryCodesService` in `amuwak_core` alongside `MfaService`,
translating errors into `AuthFailure` with the existing `retryable` flag so a
dropped connection is not reported as a bad code. Two asymmetric paths:

- `generate()` calls the `generate_mfa_recovery_codes` RPC **directly**. The
  caller is at `aal2` and needs no elevated privilege, so no Edge Function is
  involved.
- `redeem(code)` calls the **Edge Function**, never the RPC directly. The RPC
  alone would burn the code without deleting the factor, leaving the user
  locked out and a code spent.

**Enrolment** — on successful `submitCode`, the screen generates codes and shows
them once: the ten codes, a Copy action, and an "I've saved these" confirmation
that is the only way to close the screen. Only then does `onCompleted` fire.

**Challenge** — a "Use a recovery code" action alongside Verify, switching the
form to a recovery-code field. On success: `refreshSession()`, and the gate
routes onward on its own. (The dashboard "Two-factor is now off" notice
sketched here was dropped from the implementation — the Account screen
already shows two-factor's current state whenever it's opened, so a
redundant notice was cut.)

**Account** — when two-factor is on, a "Regenerate recovery codes" action
reusing the same codes screen. Regenerating invalidates the previous set.

## Testing

**pgTAP** (`supabase/tests/0054_mfa_recovery_codes_test.sql`):
- `authenticated` cannot SELECT, INSERT, UPDATE or DELETE the table directly.
- `generate_mfa_recovery_codes` raises for an `aal1` caller — named for the
  bypass it prevents.
- It returns ten codes for an `aal2` caller, and replaces any previous set.
- `redeem_mfa_recovery_code` accepts a valid code once and burns it.
- A second redemption of the same code returns `false`.
- Another user's code returns `false`.
- A redemption leaves the caller's other codes untouched (revised from the
  original plan of "clears the rest" — see the ordering note above).
- `clear_mfa_recovery_codes` removes the caller's remaining unused codes,
  keeping burned rows as the audit trail.

**Dart**:
- `RecoveryCodesService`: happy path, wrong code, and a retryable network
  failure surfacing as `retryable`.
- Codes screen: cannot be dismissed without confirming; shows all ten.
- Challenge screen: the recovery branch calls the service and refreshes the
  session on success; a wrong code keeps the field usable.
- Gate: unchanged — the existing "moves on by itself once the challenge is
  cleared" test already covers the routing this depends on.

## Scope

Migration + pgTAP, one Edge Function, one core service, one new screen, a branch
on the challenge screen, and an Account entry. Roughly doubles the diff of
PR #105 as it stands.

## Deployment note

The Edge Function must be deployed and migration 0054 pushed before the UI is
useful. Per existing project notes, remote Supabase is already behind on
migrations, so this lands in that same queue rather than ahead of it.
