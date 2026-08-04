# Interim account recovery — design

Date: 2026-08-04
Status: approved, ready for an implementation plan

## The problem

Nothing in either app can send an email. Phase A of
`docs/superpowers/plans/2026-07-29-auth-identity-hardening.md` — custom SMTP,
verified domain, Send Email Hook — is unstarted, and it is blocked behind a
domain the project does not own.

That is not one dormant feature. **Three flows rest on the same unproven pipe:**

| Flow | Entry point | State |
| --- | --- | --- |
| Customer password reset | `/forgot-password` | Shipped in #104, undeliverable |
| Staff invite / onboarding | `invite-staff` Edge Function | Undeliverable |
| Staff password reset | Login screen | Undeliverable |

So a locked-out customer has no way back in, and **a new rider cannot be
onboarded at all**.

### A second, independent defect in the same area

`supabase/functions/invite-staff/index.ts:181` sends its set-password email
with `resetPasswordForEmail` on a plain `createClient(supabaseUrl, anonKey)`.
supabase-js defaults to the **implicit** flow, so no `code_challenge` is sent
and GoTrue builds the link as `#access_token=…&type=recovery`. Both Flutter
apps run **PKCE**, and `supabase_flutter`'s `_isAuthCallbackDeeplink`
(`supabase_auth.dart:183-189`) accepts an `access_token` fragment only when the
client flow is implicit. Mismatched, the link is ignored outright — no
exchange, no error, no event. The invitee lands on the login screen with
nothing explaining why.

On the staff PWA a second problem stacks on it: `#access_token=` collides with
the app's hash-strategy routes.

**This is a theory, not a finding.** It rests on supabase-js's default flow
type. It is cheap to confirm and MUST be confirmed by walk 3 below before
anything is built on it. If confirmed, the fix already exists: the `token_hash`
path in #108 is neither PKCE nor implicit, so applying it to `invite-staff`
resolves the mismatch.

## Decisions

Taken with the user on 2026-08-04:

1. **Staged, not all at once** — prove the flows against the free built-in
   mailer before building any delivery infrastructure. Auth-flow bugs are code
   bugs; no amount of SMTP configuration fixes them, and debugging both at once
   is worse than debugging either.
2. **Verify on `localhost` first, merge after.** The bugs being hunted
   reproduce identically on localhost, and the loop is minutes instead of a
   deploy per attempt.
3. **Production email is deferred.** The project owns no domain and no
   subdomain it controls DNS for, and buying one was declined.
4. **The stand-in is staff-issued temporary passwords, covering customers AND
   staff** — because staff onboarding is blocked by the same pipe, and solving
   only the customer side still leaves the team unable to hire.
5. **The self-service entry point hides behind a build-time flag**, so
   switching it on the day a domain exists is a CI variable and a redeploy, not
   a code change and a review.

Explicitly **not** in this design, all of it waiting on a domain: Postmark, the
Send Email Hook, Supabase Pro, Turnstile, and flipping the recovery template to
`token_hash` (#108 already carries that code).

## Piece 1 — Interim honesty

`SELF_SERVICE_RESET`, a `--dart-define` read in `AppConfig` beside the existing
Supabase values, **defaulting to false**.

When false:

- the customer login screen's "Forgot password?" becomes "Contact Amuwak to
  reset your password";
- `kForgotPasswordRoute` redirects to `/login`, so a bookmarked URL cannot
  reach a dead end.

The flag gates the **entry point only**. The reset screens, routes and tests
stay in the tree untouched, so nothing rots and #108 stays exercisable.

What this actually fixes: the app currently tells every user *"if an account
exists for that address, we have sent it a link"* — and that sentence is false
for all of them.

## Piece 2 — Stage-A verification

A findings exercise with a fixed protocol, not a feature. Run on `localhost`
against the hosted Supabase project.

**Setup**

- Add `http://localhost:*` to Redirect URLs.
- Confirm the recovery link expiry is long enough to act on.
- Confirm the test address is a project team member — the built-in mailer
  delivers only to team members, and only a couple of times an hour.

**Walks, in order.** Each failure mode is distinct and diagnosable.

1. **Customer reset, same browser.** Request → click → land on
   `/reset-password` → set a password → get signed out → sign in with the new
   one. Establishes the baseline works at all.
2. **Customer reset, second browser.** Expected: `/recovery-link-error`. A
   silent bounce to `/login` instead means #104's detection is wrong.
3. **Staff invite.** Invite a rider to a second address. This carries the
   flow-mismatch theory: a link that does nothing at all — no error, no screen,
   no event — confirms it.

**Output:** a written list of what broke, appended to the auth-hardening plan.
Nothing is built on the mismatch theory until walk 3 has been run.

## Piece 3 — Staff-issued temporary passwords

### Shape

One Edge Function, `issue-temporary-password`, holding the service-role key —
same shape as `reset-staff-mfa` from #106. It:

1. takes a target (`customer_id` or `staff_id`);
2. generates a password;
3. sets it with `admin.updateUserById`;
4. flags the account must-change;
5. writes an audit row;
6. returns the password **once** in the response body.

The staff app shows it on screen for the rider to read aloud. It is never
logged, never stored, never emailed.

### Where the user lands afterwards is already built

The must-change flag feeds the same gate input the recovery latch uses —
`AuthGate._recovering` on staff, `customerAuthRedirect(recovering:)` on
customer. A temporary password therefore drops the user on the set-password
screens that #104 and #107 hardened, reload-proofing included.

No new screens for the password change itself. Only the staff-side issuing UI
is new.

### Permissions

A service-role function that can set any password is the most dangerous thing
in the codebase.

- **Staff targets: managers only.** If a driver could issue a temporary
  password for a manager, one stolen rider phone becomes full administrative
  takeover. This is the rule that matters most.
- **Customer targets: any active staff member.** Riders are the ones standing
  in front of the customer.
- **Manager resetting another manager: allowed.** Lateral, not escalation —
  both already hold full rights — and blocking it deadlocks the fleet when two
  managers are locked out.
- **The caller must be active, not soft-deleted, and owe no MFA challenge.**
  The rule from #106: a locked-out manager still holds a valid aal1 session, so
  without this a stolen password alone is enough.
- Every issuance writes an insert-only audit row: actor, target, kind,
  timestamp.

### Schema

A migration adding:

- the insert-only audit table (shape mirrors 0055);
- `customers.must_change_password`;
- a rename of `staff.must_change_pin`. The column has existed since
  `0002_staff_and_customers.sql:15`, is synced into Drift and mapped from
  Supabase, and **nothing has ever read it** — it appears only in generated
  code. Repurposing it is right; keeping a name that says "pin" while it holds
  a password flag is how the next person loses an hour.

### Resolved details

- **Temp password format:** 12 characters from an unambiguous alphabet, shown
  grouped (`4K7M-9PQR-2XTY`). Shorter to read across a counter than a word
  list, and it is spent within a minute.
- **Expiry:** none in v1. The must-change flag means it is consumed on the next
  sign-in, which happens in person, seconds later. Revisit with a `pg_cron`
  scrambler if the flow turns out to be used remotely.

## Known limitation, accepted

With no email, a customer **cannot be told their password was reset**. That is
exactly the notification OWASP asks for and Phase D was meant to deliver. A
rogue or careless rider issuing themselves access to a customer account is
invisible to that customer; the audit trail is the only control, and it is
after the fact.

This is a cost of deferring email, not something this design can engineer away.
It is the strongest argument for revisiting the domain decision.

## Testing

- The flag and the gate routing are unit-testable and get TDD'd like everything
  else.
- The Edge Function is the gap: the repo has no harness for Deno functions and
  `invite-staff` has none either. Its permission rules get a written manual
  checklist, with **driver-cannot-reset-a-manager marked non-optional** —
  exactly how #106 handled the same gap.

## Sequencing

Pieces are independently mergeable, in this order:

1. Piece 1 (flag) — no dependencies.
2. Piece 2 (verification) — no code, needs dashboard access.
3. Piece 3 (temporary passwords) — leans on #106's audit-table and
   permission-check patterns, which live on the unmerged
   `feat/mfa-manager-reset` branch. Either follow that branch in, or duplicate
   its migration shape.

Deploy order within piece 3, from #106's lesson: `supabase db push` (migration)
→ `functions deploy` → merge. The function before its audit table means every
issuance is silently unaudited.
