# Auth & identity hardening — customer + staff apps

## Context

A customer who forgets their password is permanently locked out of the customer
PWA: sign-in is the only entry point and there is no path off it. That is the
immediate trigger.

The wider goal is enterprise-grade auth across both apps. Today neither app has
a second factor, the customer app enforces a 6-character password while the
staff app enforces 8, no email has ever actually been delivered (signup relies
on `mailer_autoconfirm: true`), and there is no CAPTCHA, no breach screening,
and no notification when a password changes.

This plan covers **auth and identity only**. Remaining enterprise dimensions are
listed at the end as a roadmap, not planned here.

### Governing standards

- **NIST SP 800-63B Rev. 4** (July 2025): 8-character minimum *when a second
  authenticator exists* (15 if the password stands alone), support up to 64,
  **SHALL NOT** impose character-composition rules, **SHALL NOT** force periodic
  rotation, and screen against breach corpora.
- **OWASP Forgot Password Cheat Sheet**: enumeration-safe responses, no
  auto-login after reset, confirmation email on change, `Referrer-Policy`.

Decision: **TOTP MFA + 8-character minimum**, not a 15-character minimum. TOTP
is free on all Supabase projects, and 15 characters on a consumer app used from
a phone would cost more in abandoned signups than it buys.

Deliberately **not** enabling Supabase's required-character-set option. NIST
prohibits composition rules; length plus breach screening replaces them.

## Prerequisite (blocking, owner: Robin)

Live Supabase credentials are in this public repo's git history. If the
`service_role` key is among them it bypasses RLS entirely, and every control
below is theatre until the keys are rotated and the history purged. The `anon`
key is public by design — it ships in the web bundle — and is not the concern.

## Phase A — Platform configuration (no app code, owner: Robin)

Originally written as one blocking blob. It is not: **only the parts that put
mail in a stranger's inbox need a domain.** Split accordingly on 2026-08-04,
because the rest unblocks three broken flows for the price of a dashboard
session.

### A1 — Doable today, no domain required

- **Recovery email must link with a token hash, not `{{ .ConfirmationURL }}`.**
  That default resolves to a PKCE `?code=`, which can only be exchanged against
  a verifier held in the localStorage of the browser that *requested* the reset
  — so a link requested on a laptop and opened on a phone, or in an email
  client's own in-app browser, cannot complete at all. Emit instead:

      {{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=recovery

  Where this lives depends on the sender: with Supabase's built-in mailer it is
  Dashboard → Authentication → Emails (mirror of `supabase/templates/`); once
  the Send Email Hook is live it is the hook's own template, built from the
  payload's `token_hash` and `redirect_to`. `{{ .RedirectTo }}`, never a
  hardcoded origin — one template serves both apps and the Site URL can only
  name one of them.

  **This is also the fix for staff invites**, which are very likely broken
  today and silently so. `invite-staff` sends via `resetPasswordForEmail` on a
  supabase-js client that defaults to the *implicit* flow, while both Flutter
  apps run *PKCE*; `supabase_flutter`'s `_isAuthCallbackDeeplink` accepts an
  `access_token` fragment only for an implicit client, so the link is ignored
  outright — no exchange, no error, no event. A token hash is neither flow, so
  the mismatch has nothing left to mismatch, and the fragment/hash-route
  collision on the staff PWA goes with it. `invite-staff` needs **no code
  change**.

  **Ordering trap:** merge and deploy the app-side support (#104 → #107 →
  #108) *before* flipping the template. Backwards breaks the `?code=` links the
  deployed apps do understand. Low stakes while no mail reaches anyone; not low
  the moment a sender exists.
- Redirect URLs: add `https://amuwak-customer.pages.dev/**`, and
  `http://localhost:*` for the verification walks. Today's Site URL targets the
  staff app (`docs/staff-invites.md:48`), so without this a customer reset lands
  in the wrong application.

  One asymmetry to keep in mind when adding them: the customer PWA passes its
  own origin, but the staff app passes none and leans on the Site URL naming
  it. That is deliberate — staff is served from a Pages sub-path (`/amuwak/`)
  that a bare origin would drop — but it means moving the Site URL to the
  customer app silently breaks riders' reset links, and staff would have to
  start passing an explicit origin-plus-base-path first.
- Auth settings: minimum length **8**; required character sets **off** (per
  NIST).
- Verify in dashboard: recovery-link expiry (long enough for a new hire to
  act), and whether a password change revokes other sessions.

### A2 — Blocked on owning a sending domain

Declined for now (2026-08-04): the project owns no domain and no subdomain it
controls DNS for, and buying one was ruled out. Until this lands, **no email
reaches anyone outside the Supabase team members**, and the built-in mailer is
capped at a couple of sends an hour. See the interim phase below.

- **Postmark**: verify the sending domain with SPF, DKIM and DMARC. Chosen over
  Resend now that cost is not a constraint — 98%+ inbox placement, ~10s median
  delivery, and it accepts only transactional mail, so shared-IP reputation
  cannot be damaged by other tenants' marketing.
- **Send Email Hook** → Postmark. Replaces Supabase's built-in sender, fires on
  `recovery`, and gives real templates instead of the dashboard editor.
- **Supabase Pro** — required for Leaked Password Protection (HIBP); also brings
  PITR and longer log retention. Independent of the domain, but pointless to
  buy before mail works.
- Auth settings: leaked password protection **on** (needs Pro).
- **Cloudflare Turnstile** on auth endpoints.

## Phase A-interim — Account recovery while A2 is deferred

Design: `docs/superpowers/specs/2026-08-04-interim-account-recovery-design.md`.

With A2 deferred, three flows have no delivery: customer reset, staff invite,
staff reset. A locked-out customer has no way back in and **a new rider cannot
be onboarded at all**. Three pieces stand in:

1. **`SELF_SERVICE_RESET` build flag, default off.** Hides the customer app's
   "Forgot password?" behind "Contact Amuwak to reset your password", and
   redirects `/forgot-password` to `/login`. Gates the entry point only — the
   screens, routes and tests stay in the tree. Fixes an app that currently
   tells every user *"if an account exists, we have sent it a link"* when that
   is false for all of them.
2. **Verification walks** on `localhost` against the hosted project, using the
   built-in mailer to a team-member address: customer reset same-browser,
   customer reset second-browser, staff invite. Walks 2 and 3 only after the
   A1 template flip.
3. **Manager-issued temporary passwords**, for customers and staff alike. One
   `issue-temporary-password` Edge Function on the service-role key, shaped
   like `reset-staff-mfa` from #106: generate, set, flag must-change, audit,
   return once for the manager to read aloud. The must-change flag rides as an
   access-token claim (both gates are synchronous, and the staff app's Drift
   copy is empty on a first sign-in), and it lands the user on the set-password
   screens #104/#107 already hardened.

   **Managers only, for every target.** For staff that is non-negotiable — a
   driver who could issue a manager's password turns one stolen rider phone
   into administrative takeover. For customers it is a deliberate tightening
   over the first draft: a rider doing it is account takeover of a third party.
   The cost is that a rider in front of a locked-out customer must reach a
   manager; if that proves too slow the lever is `in_shop`, not drivers.

**Accepted limitation:** without email nobody can be *told* their password was
reset — precisely the notification Phase D exists to provide. The audit table
is the only control and it is after the fact. This is the strongest argument
for revisiting the domain decision.

## Phase B — Customer password reset (code)

**The reset link carries auth state, not navigation.** `redirectTo` is the
origin root. Supabase appends `?code=…`, `supabase_flutter` exchanges it on
init, firing `passwordRecovery`; the router then routes on that state. This
matters because the app uses Flutter web's default **hash** URL strategy (no
`usePathUrlStrategy()` in `customer_bootstrap.dart`) with PKCE — a `redirectTo`
naming a route would produce `…/#/reset-password?code=…`, a query string after a
fragment.

Task-by-task, TDD, one commit each:

- **B1** — `customerAuthRedirect` gains `bool recovering`, evaluated second:
  1. `!signedIn` → `/login` (auth pages now include `/forgot-password`)
  2. `recovering` → `/reset-password`  ← new
  3. staff role → `/staff-account`
  4. `role == 'none'` → `/complete-profile`
  5. on an auth page or interstitial → `/`

  Signed-out stays first: no session, nothing to update against. Recovery
  outranks staff and `'none'` deliberately — a stranded account sets its
  password first, *then* finishes setup. The function stays pure, so recovery is
  tested in the same matrix as PR #103.

- **B2** — sticky recovery provider beside `customer_session.dart`: seeded from
  `currentAuthEventProvider`, latched on `passwordRecovery`, cleared on
  `signedOut`. A background token refresh mid-reset must not eject the user —
  the hazard `auth_gate.dart:15` already documents. Add `ref.listen` on it to
  the router's existing `refreshListenable`.

- **B3** — core `sendPasswordReset(String email, {String? redirectTo})` in
  `packages/amuwak_core/lib/src/auth/auth_service.dart`.

- **B4** — `password_reset_controller.dart`, injectable, mirroring
  `SignupController` / `CompleteProfileController` so logic unit-tests without
  pumping widgets.

- **B5** — `forgot_password_screen.dart` (generic confirmation regardless of
  whether the address is registered) and `reset_password_screen.dart` (new
  password + confirm). **On success: sign out and route to `/login`** — OWASP
  requires a normal login afterwards rather than auto-login, and this clears the
  sticky flag via the `signedOut` event.

- **B6** — `apps/amuwak_customer/web/_headers` (Cloudflare Pages serves it):

  ```
  /*
    Referrer-Policy: no-referrer
  ```

  The reset URL carries `?code=…`; without this a third-party resource on the
  page can leak it via `Referer`.

## Phase C — One password policy

Signup requires 6 (`signup_screen.dart:118`), staff set-password requires 8
(`set_password_screen.dart:143`). Extract a single validator into `amuwak_core`
— 8 minimum, no composition rules, no maximum below 64 — used in customer
signup, customer reset, and staff set-password.

Also fix the staff wording in `apps/amuwak_staff/lib/src/auth/login_screen.dart`:
it claims *"Sent a password reset link to X"*, asserting delivery that did not
happen for an unregistered address, and surfaces raw `AuthFailure.message`
(rate-limit text) to users. This is *not* an enumeration leak — Supabase's
endpoint is enumeration-safe by design — but the wording is wrong either way.

## Phase D — Password-changed notification

The Send Email Hook has no "password changed" event, so this needs a Postgres
trigger on `auth.users` (encrypted_password change) calling an Edge Function
that sends via Postmark. Trigger-based rather than app-side so it also catches
changes made from the Supabase dashboard. This is OWASP's account-takeover
detection mechanism: it is how a victim finds out.

## Phase E — TOTP MFA

Sequence carefully; enforcement before enrolment locks staff out of production.

1. Core `MfaService` wrapping `enroll` / `challenge` / `verify`, plus recovery
   codes.
2. Staff: enrolment UI, then challenge-on-sign-in. **Enrol everyone before
   enforcing.**
3. Only then require `aal2` in staff RLS policies — a migration, and the step
   that can lock people out.
4. Customer: optional enrolment from the profile screen.

Skip the phone/SMS add-on ($75/month); TOTP is free and stronger.

## Verification

- Unit-test `customerAuthRedirect` for recovery across the matrix: outranks
  staff and `'none'`, signed-out still wins, no ping-pong at `/reset-password`,
  `/forgot-password` reachable while signed out.
- Unit-test `PasswordResetController`: ordering, and that a failed
  `updatePassword` neither signs the user out nor clears the flag.
- Widget-test both screens as in PR #103 — validators, busy-state locking, error
  banner, and that success signs out rather than landing on `/`.
- `flutter analyze` clean; run each test file singly (this host crashes the
  Flutter tool on concurrent `flutter test` runs in one worktree).
- pgTAP for the Phase D trigger.
- **Live E2E, part one** (needs only A1): the three verification walks in Phase
  A-interim, on `localhost` against the hosted project, delivered by the
  built-in mailer to a team-member address. Enough to prove the link shape, the
  routing and the invite fix.
- **Live E2E, part two** (needs A2): request a reset for a real address;
  confirm it arrives from Postmark (SPF/DKIM pass in headers, not in spam);
  follow the link; confirm it lands on the reset screen and not the staff app;
  set a password; confirm a fresh login is required and the notification email
  arrives. Then confirm a known-breached password is rejected by HIBP.

## Roadmap — not in this plan

Backups and DR drills (PITR restore actually rehearsed), audit logging of
privileged actions, WAF and abuse controls beyond Turnstile, observability and
alerting, dependency and secret scanning in CI, and the git-history credential
purge noted as the prerequisite above.
