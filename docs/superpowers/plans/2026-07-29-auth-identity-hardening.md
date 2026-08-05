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

- **Supabase Pro** — required for Leaked Password Protection (HIBP); also brings
  PITR and longer log retention.
- Auth settings: minimum length **8**; leaked password protection **on**;
  required character sets **off** (per NIST).
- **Postmark**: verify the sending domain with SPF, DKIM and DMARC. Chosen over
  Resend now that cost is not a constraint — 98%+ inbox placement, ~10s median
  delivery, and it accepts only transactional mail, so shared-IP reputation
  cannot be damaged by other tenants' marketing.
- **Send Email Hook** → Postmark. Replaces Supabase's built-in sender, fires on
  `recovery`, and gives real templates instead of the dashboard editor.
- **Cloudflare Turnstile** on auth endpoints.
- Redirect URLs: add `https://amuwak-customer.pages.dev/**`. Today's Site URL
  targets the staff app (`docs/staff-invites.md:48`), so without this a customer
  reset lands on the wrong application.
- Verify in dashboard: recovery-link expiry, and whether password change revokes
  other sessions.

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
- **Live E2E** (needs Phase A): request a reset for a real address; confirm it
  arrives from Postmark (SPF/DKIM pass in headers, not in spam); follow the
  link; confirm it lands on the reset screen and not the staff app; set a
  password; confirm a fresh login is required and the notification email
  arrives. Then confirm a known-breached password is rejected by HIBP.

## Roadmap — not in this plan

Backups and DR drills (PITR restore actually rehearsed), audit logging of
privileged actions, WAF and abuse controls beyond Turnstile, observability and
alerting, dependency and secret scanning in CI, and the git-history credential
purge noted as the prerequisite above.
