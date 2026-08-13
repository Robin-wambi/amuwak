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

`supabase/functions/invite-staff/index.ts:177` sends its set-password email
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

**Decision (2026-08-04): fix it on the reasoning, do not wait for a
reproduction.** The fix is free, so the cost of being wrong about the diagnosis
is zero.

`invite-staff` needs **no code change**. It keeps calling
`resetPasswordForEmail`, so Supabase keeps sending and keeps using the recovery
template — and flipping that template to a token hash removes the mismatch
entirely, because `?token_hash=…&type=recovery` is neither PKCE nor implicit.
`completeRecoveryLink` (#108) redeems it whatever the client flow is. The
fragment/hash-route collision on the staff PWA goes with it, since nothing
lands in the fragment any more.

Walk 3 below still runs, but as confirmation that invites now work — not as a
gate on building anything.

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

6. **Flip the recovery email template to `token_hash` now.** Corrects an error
   in the first draft of this spec, which parked the flip alongside the rest of
   Phase A. It does not belong there: the template is a dashboard setting, and
   only the *sender* waits on DNS. Flipping it is also the entire fix for the
   `invite-staff` mismatch above.

Explicitly **not** in this design, all of it genuinely waiting on a domain:
Postmark, the Send Email Hook, Supabase Pro, and Turnstile.

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
3. **Staff invite.** Invite a rider to a second address, and confirm the link
   now lands on the set-password screen. This is the walk that proves the
   template flip fixed the mismatch.

Walks 2 and 3 are only meaningful **after** the template flip, since both
depend on the link shape. Walk 1 is worth running before and after: before, it
establishes the PKCE path was working at all, which is what tells you a later
failure came from the flip rather than from something that never worked.

**Output:** a written list of what broke, appended to the auth-hardening plan.

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

**How the apps read the flag.** Both gates are synchronous and run before any
data is fetched, so the flag travels as a **claim on the access token**, minted
by the existing `custom_access_token_hook` alongside `user_role` (migration
0009/0025/0043). Not a table read: the customer gate has no session-scoped
query at that point, and the staff app's Drift copy of `staff` is empty on a
first sign-in — exactly the case this has to handle.

The claim clears naturally. Completing a set-password signs the user out, so
the next sign-in mints a fresh token without it. That is the same mechanism
that already ends recovery, and it means no cache to invalidate.

### Permissions

A service-role function that can set any password is the most dangerous thing
in the codebase.

- **Managers only, for every target — staff and customer alike.** For staff
  targets this is non-negotiable: if a driver could issue a temporary password
  for a manager, one stolen rider phone becomes full administrative takeover.
  For customer targets it is a deliberate tightening (decided 2026-08-04): a
  rider issuing a customer password is account takeover of a third party, and
  with no email the customer can never be told it happened.

  The cost is real and should be planned for. A rider standing in front of a
  locked-out customer cannot fix it themselves — they have to reach a manager,
  who issues the password and passes it back. If that turns out to be too slow
  in practice, the lever to reconsider is `in_shop` (present at the counter,
  not administrative), not drivers.
- **Manager resetting another manager: allowed.** Lateral, not escalation —
  both already hold full rights — and blocking it deadlocks the fleet when two
  managers are locked out.
- **The caller must be active, not soft-deleted, and owe no MFA challenge.**
  The rule from #106: a locked-out manager still holds a valid aal1 session, so
  without this a stolen password alone is enough.
- Every issuance writes an insert-only audit row: actor, target, kind,
  timestamp.
- **Rate limited per caller.** An endpoint that can set any password, with no
  ceiling, is worth stealing a session for. The audit table is the natural
  place to enforce it — reject when the caller has issued more than a small
  number in the last hour — which also means the abuse and the limit share one
  source of truth.

### Schema

A migration adding:

- the insert-only audit table (shape mirrors `0056_mfa_reset_audit.sql`);
- `customers.must_change_password`;
- a rename of `staff.must_change_pin`. The column has existed since
  `0002_staff_and_customers.sql:15` and is written by hand-written sync code
  (`supabase_mappers.dart:44`, `sync_puller.dart:236`) as well as appearing in
  generated Drift code — but **nothing has ever acted on the value**: no UI, no
  gate, no branch reads it. Repurposing it is right; keeping a name that says
  "pin" while it holds a password flag is how the next person loses an hour.

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
rogue or careless manager issuing themselves access to a customer account is
invisible to that customer; the audit trail is the only control, and it is
after the fact.

Restricting issuance to managers narrows who can do this, but does not change
that nobody outside the audit table would ever know.

This is a cost of deferring email, not something this design can engineer away.
It is the strongest argument for revisiting the domain decision.

## Testing

- The flag and the gate routing are unit-testable and get TDD'd like everything
  else.
- The Edge Function is the gap: the repo has no harness for Deno functions and
  `invite-staff` has none either. Its permission rules get a written manual
  checklist, with **non-manager-cannot-issue-anything marked non-optional** —
  exactly how #106 handled the same gap.

## Sequencing

1. **Merge the auth stack** — #104 → #107 → #108, retargeting as each lands.
   The apps must be able to redeem a `token_hash` link *before* the template
   emits one.
2. **Flip the recovery template** (dashboard; mirror of
   `supabase/templates/recovery.html`). This is the `invite-staff` fix.
3. **Piece 2, the verification walks.** Walk 1 is worth running either side of
   step 2; walks 2 and 3 only after it.
4. **Piece 1, the flag.** No dependencies — it can move in parallel with all of
   the above.
5. **Piece 3, temporary passwords.** Leans on #106's audit-table and
   permission-check patterns, which have since shipped: `is_active_manager()`
   is in `0055_min_two_managers.sql` and the audit-table shape is
   `0056_mfa_reset_audit.sql`. Reuse both rather than duplicating them.

Order within step 1 matters and is easy to get backwards. Flipping the template
before the apps are deployed breaks the `?code=` links they *do* understand.
That is a small risk today, since no email reaches a real user anyway, but it
stops being small the moment a sender exists.

Deploy order within piece 3, from #106's lesson: `supabase db push` (migration)
→ `functions deploy` → merge. The function before its audit table means every
issuance is silently unaudited.
