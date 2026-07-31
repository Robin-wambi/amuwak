# MFA recovery: manager-mediated reset

## Problem

Supabase TOTP has no native recovery codes. A staff member who loses their
authenticator cannot pass the challenge, and PR #105 shipped MFA with only an
operational escape hatch: sign out, and ask someone to unenrol the factor from
the Supabase dashboard. That is acceptable while MFA is optional. It is not
acceptable once `aal2` is enforced in RLS, because the fallback depends on one
person with dashboard access being reachable.

## The constraint that shapes everything

**A recovery mechanism cannot satisfy the MFA challenge.** GoTrue mints the
`aal` claim; nothing written in this codebase can produce an `aal2` session. So
recovery cannot be "a second way to pass the check" — it can only *remove the
factor*, dropping the account to `aal1`.

`auth.admin.mfa.deleteFactor({id, userId})` does this with the service-role key,
and signs the target out of all sessions when the deleted factor was verified.
That is convenient rather than a problem: the target lands at login, signs in
with their password alone, and is prompted to enrol again.

## Decisions

Recovery is **manager-mediated**, not self-service recovery codes. Riders work
from cheap, shared and easily-lost phones; ten printed single-use codes would
be absent exactly when needed. A manager in the shop is a reachable recovery
desk. (NIST would class recovery codes as look-up secrets under SP 800-63B
§5.1.2 — ≥20 bits entropy, single-use, salted and hashed below 112 bits,
rate-limited below 64 bits. Not built here, but that is the bar if it is ever
revisited.)

**Any manager may reset any other manager. Nobody may reset themselves.**

**At least two active managers must exist**, enforced by a database trigger, so
a locked-out manager always has a colleague who can help.

## Architecture

### Edge Function `reset-staff-mfa`

Mirrors `supabase/functions/invite-staff`, which is the established pattern for
a privileged action behind a server-side role check.

1. Identify the caller from the `Authorization` JWT.
2. Read the caller's **raw** `staff.role` and `active` with the service-role
   client.
3. Apply the authorisation rules below.
4. Resolve the target by `staff.id`, which the list already holds and which
   equals the auth user id (migration 0002). Not by username: usernames are
   mutable and a rename between listing and tapping would silently retarget.
5. `admin.mfa.listFactors({userId})`, then `admin.mfa.deleteFactor` for each
   verified factor.
6. Insert an audit row.
7. Return `{ factorsCleared: n }`.

### Authorisation rules

**Caller is an active manager.** Checked against the raw `staff.role` column,
deliberately NOT `auth_staff_role()` — migration 0039 makes that helper return
`'manager'` for drivers, so every RLS policy checking for a manager is already
satisfied by a driver. RLS cannot be the boundary for this action.

**Caller does not owe an MFA challenge.** This is the rule that makes the
feature safe rather than a hole. Once enforcement lands, a locked-out manager
still holds a valid `aal1` session — password accepted, challenge outstanding.
The app hides the UI, but the JWT works. Without this check, a stolen password
alone would let an attacker strip 2FA off any account, and MFA would be
decorative.

Expressed as: *if the caller has a verified factor, their JWT `aal` must be
`aal2`*. Not a flat `aal2` requirement — nobody has enrolled yet, and a flat
rule would make the feature unusable during the optional phase.

**Caller is not the target.** A manager holding `aal2` can already unenrol
themselves via `MfaService.removeFactor`, so self-reset adds nothing here and
would only muddy the audit trail.

### Two-manager minimum (trigger)

On `UPDATE` and `DELETE` of `staff`: if the change removes an active manager and
fewer than two would remain, raise. There are four ways to remove one, and the
trigger must cover all of them — `role` changed away, `active` set false,
`deleted_at` set (the table soft-deletes, migration 0002), or a hard `DELETE`.
Missing the soft-delete path would leave the obvious route wide open.

"Active manager" throughout means `role = 'manager' AND active AND deleted_at IS
NULL`, and the same predicate must be used by the count and by the Edge
Function's caller check, or the two will disagree about who exists.

Fires only on changes that *decrease* the active-manager count. Deactivating a
driver is unaffected, and promoting someone to reach two is always allowed, so
an estate currently sitting at one manager can still climb out.

A trigger rather than RLS or app logic, for the 0039 reason above: an
RLS-based guard would let a driver demote the managers.

### Audit

Table `mfa_reset_audit`: actor staff id, target staff id, factors cleared,
timestamp. This action deliberately weakens another person's account security
and should never be invisible. Managers may read it; nobody may write it except
the function (service role).

### UI

A managers-only staff list under Account → Staff. `staff_self_read` (migration
0007) already lets managers select every staff row, so the read needs no
migration.

The list does **not** show per-person 2FA status. Factor status is admin-only
data, so displaying it would require a second privileged endpoint for cosmetic
value. The action is idempotent instead and reports what it did, including
"nothing to clear".

Tap a staff member → confirmation dialog naming them → call the function →
snackbar reporting the outcome.

## Error handling

- Non-manager caller, or caller owing a challenge, or self-target → 403 with a
  generic message; the app shows "You cannot do that" rather than echoing which
  rule failed.
- Unknown target → 404.
- Target has no verified factor → success with `factorsCleared: 0`, surfaced as
  "X had no two-factor set up".
- Trigger rejection on the two-manager rule → surfaced in the UI as an
  explanation, not a raw database error.

## Testing

- pgTAP for the trigger, one case per removal path: demote, deactivate,
  soft-delete, hard delete. Plus the negatives — unrelated staff changes are
  unaffected, promotion to reach two is allowed, and removing a manager while
  three exist is allowed.
- pgTAP for `mfa_reset_audit` RLS.
- Dart unit tests for the service wrapper (success, 403, 404, zero-factor).
- Widget tests for the staff list and the confirmation flow, following the
  `invite_staff` shape.
- The Edge Function has no local test harness — `invite-staff` has none either.
  It is verified by deploying to the project and exercising it against a real
  enrolled account.

## Operational prerequisites

**A second manager must actually exist.** The trigger will hold the line at one
manager quite happily; it cannot invent a colleague. If production currently has
a single manager, invite a second with role `manager` before enforcement.

A single-manager estate falls back to the Supabase dashboard, which means the
project owner personally. Document this in the runbook.

## Out of scope

- Self-service recovery codes.
- The `aal2` RLS enforcement migration (Phase E step 3) — still a separate,
  deliberate step, and this spec is a prerequisite for it rather than part of it.
- Role changes from the staff list. Roles are set at invite time; a second
  manager is created by inviting one.
- Customer MFA.
