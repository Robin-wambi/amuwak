# Interim Account Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give locked-out customers and un-onboarded riders a way in while email delivery is deferred, and stop the customer app promising reset emails it cannot send.

**Architecture:** Three independent pieces. A build-time flag hides the customer app's self-service reset entry point. A dashboard template flip (no code) fixes staff invites. A manager-only Edge Function issues one-time temporary passwords for customers and staff; a `must_change_password` claim on the access token routes the recipient to the set-password screens PRs #104/#107 already hardened.

**Tech Stack:** Flutter 3.32 (Riverpod, go_router, Drift), Dart 3.8, Supabase (Postgres + GoTrue + Deno Edge Functions), mocktail, pgTAP.

## Global Constraints

- Design source of truth: `docs/superpowers/specs/2026-08-04-interim-account-recovery-design.md`. Read it before starting.
- **Migration numbering starts at 0058.** `main` already carries 0054, 0055 and 0056 — #106's work shipped — and `0057_table_grants.sql` lands with #113. A duplicate prefix trips a CI guardrail, and this number goes stale every time a migration merges: run `supabase migration list` before starting and renumber if it has moved again.
- **Issuing a temporary password is managers-only, for every target — staff and customer alike.** No task may relax this.
- The Edge Function must never log, store, or email a generated password.
- TDD throughout: write the failing test, watch it fail for the right reason, then implement. Watching it fail is not optional — a test that never failed proves nothing.
- **Run `flutter test` one file at a time.** This host hangs on multi-path invocations. Use `--timeout=none` on large files. A `+0 -1` timeout on the `loading` line is the host being slow, not your code — retry.
- Never pipe test output through `tail` when you need the exit code; the pipe masks it. Redirect to a file, echo `$?`, then read the file.
- Commit with explicit paths: `git commit -- <paths>`. The branch is shared and may hold unrelated staged work.
- `flutter analyze` must be clean in every package you touch before you commit.

---

## File Structure

**Piece 1 — the flag**
- Modify `packages/amuwak_core/lib/src/bootstrap/app_config.dart` — add `selfServiceReset`.
- Modify `packages/amuwak_core/test/bootstrap/app_config_test.dart` — cover the default.
- Modify `apps/amuwak_customer/lib/src/app/router.dart` — `customerAuthRedirect` sends `/forgot-password` to `/login` when off.
- Modify `apps/amuwak_customer/lib/src/auth/login_screen.dart` — swap the button for static copy.
- Modify `apps/amuwak_customer/test/auth/router_redirect_test.dart`, `apps/amuwak_customer/test/auth/login_screen_test.dart`.

**Piece 3 — temporary passwords**
- Create `supabase/migrations/0058_password_reset_audit.sql` — audit table, customer flag, staff column rename.
- Create `supabase/migrations/0059_must_change_password_claim.sql` — extend the access-token hook.
- Create `supabase/tests/0058_password_reset_audit_test.sql`, `supabase/tests/0059_must_change_password_claim_test.sql` — pgTAP.
- Create `supabase/functions/issue-temporary-password/index.ts`.
- Modify `packages/amuwak_core/lib/src/auth/session.dart` — read the claim.
- Modify `packages/amuwak_core/test/auth/session_test.dart`.
- Modify `apps/amuwak_customer/lib/src/app/router.dart` + its test — honour the flag.
- Modify `apps/amuwak_staff/lib/src/auth/auth_gate.dart` + its test — honour the flag.
- Modify `apps/amuwak_staff/lib/src/data/tables/staff_table.dart`, `apps/amuwak_staff/lib/src/data/app_database.dart`, `apps/amuwak_staff/lib/src/sync/supabase_mappers.dart`, `apps/amuwak_staff/lib/src/sync/sync_puller.dart` — drop the dead Drift column.
- Create `apps/amuwak_staff/lib/src/staff/issue_temporary_password_service.dart` — calls the Edge Function.
- Create `apps/amuwak_staff/lib/src/staff/issue_password_screen.dart` — issues for one target and reveals the password once.
- Create `apps/amuwak_customer/test/auth/login_screen_test.dart` — does not exist today; the login screen is currently covered only through `customer_app_test.dart`.

**Not in this plan, and the feature is incomplete without it:** the staff app has no staff-list or customer-list screen, so there is nowhere to *pick* a target. `IssuePasswordScreen` is a leaf that receives one. Wire it from a surface where a manager already has the person in hand; a directory with search is a follow-up. Both `customers` and `staff` are already synced into the staff app's Drift DB, so that follow-up needs no new sync work.

---

## Task 0: Platform steps (manual, owner: Robin — no code)

Not a coding task. It gates Tasks 8–10's end-to-end verification but blocks nothing else, so it can run in parallel with Tasks 1–7.

- [ ] **Step 1: Merge and deploy the auth stack**

Merge #104 → #107 → #108, retargeting each as its base lands. Confirm both PWAs have deployed. **The apps must be able to redeem a `token_hash` link before the template emits one** — backwards breaks the `?code=` links they currently understand.

- [ ] **Step 2: Flip the recovery email template**

Supabase Dashboard → Authentication → Emails → *Reset password*. Replace the `{{ .ConfirmationURL }}` link with the body of `supabase/templates/recovery.html`, whose link is:

```
{{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=recovery
```

Never a hardcoded origin — one template serves both apps.

- [ ] **Step 3: Redirect URLs and settings**

Add `https://amuwak-customer.pages.dev/**` and `http://localhost:*`. Set minimum password length 8, required character sets off. Raise the recovery/OTP expiry to a window a new hire can act within.

- [ ] **Step 4: Run the three verification walks**

On `localhost`, against the hosted project, delivered to a Supabase team-member address (the built-in mailer reaches nobody else, ~2/hour).

1. Customer reset, same browser: request → click → `/reset-password` → set → signed out → sign in with the new password.
2. Customer reset, second browser: expect the same success now (a token hash is not browser-bound). A `/recovery-link-error` here means the template flip did not take.
3. Staff invite: invite to a second address; expect the set-password screen. **This is the walk that proves the invite mismatch is fixed.**

- [ ] **Step 5: Record the findings**

Append what actually happened to `docs/superpowers/plans/2026-07-29-auth-identity-hardening.md` under Phase A-interim. Write down failures verbatim — a paraphrased error is a lost hour later.

---

## Task 1: `SELF_SERVICE_RESET` in AppConfig

**Files:**
- Modify: `packages/amuwak_core/lib/src/bootstrap/app_config.dart`
- Test: `packages/amuwak_core/test/bootstrap/app_config_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AppConfig.selfServiceReset` (`bool`), false unless `--dart-define=SELF_SERVICE_RESET=true`.

- [ ] **Step 1: Write the failing test**

Append to `packages/amuwak_core/test/bootstrap/app_config_test.dart`:

```dart
  group('selfServiceReset', () {
    test('is off unless the build explicitly turns it on', () {
      // Reset emails cannot be delivered yet, so the default must not offer a
      // flow that silently does nothing. Opting IN is a deliberate act.
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon',
      );

      expect(config.selfServiceReset, isFalse);
    });

    test('carries the flag when constructed with it on', () {
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon',
        selfServiceReset: true,
      );

      expect(config.selfServiceReset, isTrue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/amuwak_core && flutter test test/bootstrap/app_config_test.dart --timeout=none`
Expected: compile failure — `The named parameter 'selfServiceReset' isn't defined`.

- [ ] **Step 3: Write minimal implementation**

In `app_config.dart`, add the field, constructor parameter, and environment read:

```dart
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.selfServiceReset = false,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Whether the customer app offers self-service password reset.
  ///
  /// Off by default, and that default is the honest one: no sender is
  /// configured, so a reset email reaches nobody outside the Supabase team.
  /// Offering the flow anyway means telling every user we sent them a link
  /// that does not exist. Turn on with
  /// `--dart-define=SELF_SERVICE_RESET=true` once mail is deliverable.
  final bool selfServiceReset;

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
        selfServiceReset:
            bool.fromEnvironment('SELF_SERVICE_RESET', defaultValue: false),
      );
```

Leave `validate()` untouched — a false flag is valid.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/amuwak_core && flutter test test/bootstrap/app_config_test.dart --timeout=none`
Expected: PASS, all tests in the file.

- [ ] **Step 5: Commit**

```bash
git add packages/amuwak_core/lib/src/bootstrap/app_config.dart packages/amuwak_core/test/bootstrap/app_config_test.dart
git commit -m "feat(core): SELF_SERVICE_RESET build flag, default off" -- packages/amuwak_core/lib/src/bootstrap/app_config.dart packages/amuwak_core/test/bootstrap/app_config_test.dart
```

---

## Task 2: Customer app honours the flag

**Files:**
- Modify: `apps/amuwak_customer/lib/src/app/router.dart`
- Modify: `apps/amuwak_customer/lib/src/auth/login_screen.dart`
- Test: `apps/amuwak_customer/test/auth/router_redirect_test.dart`
- Test: `apps/amuwak_customer/test/auth/login_screen_test.dart`

**Interfaces:**
- Consumes: `AppConfig.selfServiceReset` from Task 1.
- Produces: `customerAuthRedirect({..., bool selfServiceReset = true})`; `selfServiceResetProvider` (`Provider<bool>`) in `router.dart`.

Note the parameter defaults to **true** while the config default is false. The pure function stays neutral so the existing 27 redirect tests keep asserting real routing rules; the app supplies the real value.

- [ ] **Step 1: Write the failing redirect test**

Append inside the `customerAuthRedirect` group in `router_redirect_test.dart`:

```dart
    group('with self-service reset switched off', () {
      test('the forgot-password page is not reachable', () {
        // No sender is configured, so the page would promise an email that
        // never arrives. A bookmarked URL must not reach it either.
        expect(
          customerAuthRedirect(
              signedIn: false,
              selfServiceReset: false,
              location: kForgotPasswordRoute),
          '/login',
        );
      });

      test('the other auth pages are untouched', () {
        expect(
          customerAuthRedirect(
              signedIn: false, selfServiceReset: false, location: '/login'),
          isNull,
        );
        expect(
          customerAuthRedirect(
              signedIn: false, selfServiceReset: false, location: '/signup'),
          isNull,
        );
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/amuwak_customer && flutter test test/auth/router_redirect_test.dart --timeout=none`
Expected: compile failure — `The named parameter 'selfServiceReset' isn't defined`.

- [ ] **Step 3: Implement the redirect change**

In `router.dart`, add the parameter and drop the forgot-password route from the reachable set when off:

```dart
String? customerAuthRedirect({
  required bool signedIn,
  required String location,
  String? role,
  bool recovering = false,
  bool recoveryLinkFailed = false,
  bool selfServiceReset = true,
}) {
  final onAuthPage = location == '/login' ||
      location == '/signup' ||
      (selfServiceReset && location == kForgotPasswordRoute) ||
      location == kRecoveryLinkFailedRoute;
```

Leave the rest of the function alone. With the flag off, `kForgotPasswordRoute` is no longer an auth page, so a signed-out visitor there falls through to `/login` — which is exactly the wanted behaviour, and it costs no new branch.

Add the provider near `routerProvider`:

```dart
/// Whether the app offers self-service password reset. Sourced from the build
/// so a deployment can switch it on without a code change; see [AppConfig].
final selfServiceResetProvider =
    Provider<bool>((ref) => AppConfig.fromEnvironment().selfServiceReset);
```

And pass it in the router's redirect:

```dart
      selfServiceReset: ref.read(selfServiceResetProvider),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/amuwak_customer && flutter test test/auth/router_redirect_test.dart --timeout=none`
Expected: PASS — 29 tests.

- [ ] **Step 5: Write the failing login-screen test**

**This file does not exist yet** — the login screen is currently covered only indirectly, through `test/app/customer_app_test.dart`. Create `apps/amuwak_customer/test/auth/login_screen_test.dart`:

```dart
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/app/router.dart';
import 'package:amuwak_customer/src/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

/// The screen navigates with `context.go`, so it needs a router under it —
/// tapping "Forgot password?" would otherwise throw.
Widget _harness({required bool selfServiceReset}) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: kForgotPasswordRoute,
          builder: (_, __) => const Scaffold(body: Text('forgot page'))),
    ],
  );
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(_MockAuthService()),
      selfServiceResetProvider.overrideWithValue(selfServiceReset),
    ],
    child: MaterialApp.router(
        theme: buildAmuwakTheme(), routerConfig: router),
  );
}

void main() {
  testWidgets('offers a way to get help instead of a dead reset link',
      (tester) async {
    // No sender is configured, so the link would promise an email that never
    // arrives. Telling the user who to ask is the honest alternative.
    await tester.pumpWidget(_harness(selfServiceReset: false));
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsNothing);
    expect(find.textContaining('Contact Amuwak'), findsOneWidget);
  });

  testWidgets('offers self-service reset once it is switched on',
      (tester) async {
    await tester.pumpWidget(_harness(selfServiceReset: true));
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.textContaining('Contact Amuwak'), findsNothing);
  });
}
```

Add `import 'package:go_router/go_router.dart';` too.

- [ ] **Step 6: Run test to verify it fails**

Run: `cd apps/amuwak_customer && flutter test test/auth/login_screen_test.dart --timeout=none`
Expected: FAIL — `Found 1 widget with text "Forgot password?"` where none was expected.

- [ ] **Step 7: Implement the login-screen change**

`LoginScreen` must be a `ConsumerStatefulWidget` already (it reads `authServiceProvider`). Replace the forgot-password `TextButton` with:

```dart
                    if (ref.watch(selfServiceResetProvider))
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(kForgotPasswordRoute),
                        child: const Text('Forgot password?'),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                        child: Text(
                          'Contact Amuwak to reset your password.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
```

- [ ] **Step 8: Run both test files to verify they pass**

Run each separately:
`cd apps/amuwak_customer && flutter test test/auth/login_screen_test.dart --timeout=none`
`cd apps/amuwak_customer && flutter test test/app/customer_app_test.dart --timeout=none`
Expected: PASS. The second is the regression check — it drives the real router.

- [ ] **Step 9: Commit**

```bash
git commit -m "feat(customer): hide self-service reset behind the build flag" -- apps/amuwak_customer/lib/src/app/router.dart apps/amuwak_customer/lib/src/auth/login_screen.dart apps/amuwak_customer/test/auth/router_redirect_test.dart apps/amuwak_customer/test/auth/login_screen_test.dart
```

---

## Task 3: Migration 0058 — audit table and forced-change flags

**Files:**
- Create: `supabase/migrations/0058_password_reset_audit.sql`
- Test: `supabase/tests/0058_password_reset_audit_test.sql`

**Interfaces:**
- Produces: table `password_reset_audit`; column `customers.must_change_password`; column `staff.must_change_password` (renamed from `must_change_pin`).
- Consumes: `is_active_manager(uuid) → boolean`, already shipped in `0055_min_two_managers.sql`.

- [ ] **Step 1: Write the failing pgTAP test**

Create `supabase/tests/0058_password_reset_audit_test.sql`:

```sql
BEGIN;
SELECT plan(8);

SELECT has_table('password_reset_audit');
SELECT has_column('password_reset_audit', 'actor_staff_id');
SELECT has_column('password_reset_audit', 'target_kind');
SELECT has_column('password_reset_audit', 'target_id');

-- The staff flag is renamed, not duplicated: one column, correctly named.
SELECT hasnt_column('staff', 'must_change_pin');
SELECT has_column('staff', 'must_change_password');
SELECT has_column('customers', 'must_change_password');

-- No client-facing policy may grant INSERT: the log is written only by the
-- service-role key, so it cannot be forged from the app.
SELECT is_empty(
  $$ SELECT policyname FROM pg_policies
      WHERE tablename = 'password_reset_audit' AND cmd = 'INSERT' $$,
  'no INSERT policy on password_reset_audit'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run it to verify it fails**

Run: `supabase start -x storage-api,imgproxy --ignore-health-check && supabase test db`
Expected: FAIL — `password_reset_audit` does not exist.

Note: `0015_powersync` fails 15/15 on this repo and always has. A non-zero exit is only your regression if a `0058` assertion is among the failures.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0058_password_reset_audit.sql`:

```sql
-- 0058_password_reset_audit.sql
-- Email cannot be delivered yet, so a manager issues a temporary password in
-- person instead. That is a deliberate, privileged weakening of someone's
-- account and must never be invisible: who did it, to whom, and when.
--
-- Insert-only from the server. The issue-temporary-password Edge Function
-- writes with the service-role key, which bypasses RLS; no client-facing
-- policy grants INSERT, UPDATE or DELETE, so the log cannot be forged or
-- erased from the app.

-- is_active_manager() is NOT declared here. It shipped in
-- 0055_min_two_managers.sql:26 with the same body and the same grants, and
-- 0055 always applies first, so this migration simply calls it. An earlier
-- draft re-declared it defensively because #106 was unmerged; it has since
-- landed, and a second copy would only be one more thing to keep in sync.

CREATE TABLE password_reset_audit (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_staff_id uuid NOT NULL REFERENCES staff(id),
  target_kind    text NOT NULL CHECK (target_kind IN ('staff', 'customer')),
  target_id      uuid NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- target_id is polymorphic across staff and customers, so it carries no FK.
-- The CHECK on target_kind is what keeps it interpretable.
CREATE INDEX password_reset_audit_target_idx
  ON password_reset_audit (target_kind, target_id, created_at DESC);

-- Serves the per-caller rate limit as well as the audit read.
CREATE INDEX password_reset_audit_actor_idx
  ON password_reset_audit (actor_staff_id, created_at DESC);

ALTER TABLE password_reset_audit ENABLE ROW LEVEL SECURITY;

-- is_active_manager() rather than auth_staff_role(): the latter checks `active`
-- but not `deleted_at IS NULL`, so a soft-deleted manager would keep read
-- access to a security-audit log. Both exclude drivers.
CREATE POLICY password_reset_audit_manager_read ON password_reset_audit
  FOR SELECT USING (is_active_manager(auth.uid()));

-- The forced-change flags the access-token hook (0059) reads.
ALTER TABLE customers ADD COLUMN must_change_password boolean NOT NULL
  DEFAULT false;

-- Renamed, not added. The column has existed since 0002 under a name from the
-- PIN era and nothing has ever read it. Wiring up a flag whose name lies about
-- what it holds is how the next person loses an hour.
ALTER TABLE staff RENAME COLUMN must_change_pin TO must_change_password;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `supabase db reset && supabase test db`
Expected: the 8 `0058` assertions pass.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(db): audit table and forced-change flags for issued passwords" -- supabase/migrations/0058_password_reset_audit.sql supabase/tests/0058_password_reset_audit_test.sql
```

---

## Task 4: Migration 0059 — the `must_change_password` claim

**Files:**
- Create: `supabase/migrations/0059_must_change_password_claim.sql`
- Test: `supabase/tests/0059_must_change_password_claim_test.sql`

**Interfaces:**
- Consumes: the columns from Task 3.
- Produces: `custom_access_token_hook` emits a boolean `must_change_password` claim alongside `user_role`.

- [ ] **Step 1: Write the failing pgTAP test**

Create `supabase/tests/0059_must_change_password_claim_test.sql`:

```sql
BEGIN;
SELECT plan(3);

-- A staff member flagged for a forced change.
INSERT INTO staff (id, username, display_name, role, active,
                   must_change_password)
VALUES ('11111111-1111-1111-1111-111111111111', 'flagged', 'Flagged',
        'driver', true, true);

-- A staff member who is not.
INSERT INTO staff (id, username, display_name, role, active,
                   must_change_password)
VALUES ('22222222-2222-2222-2222-222222222222', 'normal', 'Normal',
        'driver', true, false);

SELECT is(
  (public.custom_access_token_hook(
     '{"user_id":"11111111-1111-1111-1111-111111111111","claims":{}}'::jsonb
   ) -> 'claims' ->> 'must_change_password'),
  'true',
  'a flagged staff member gets the claim'
);

SELECT is(
  (public.custom_access_token_hook(
     '{"user_id":"22222222-2222-2222-2222-222222222222","claims":{}}'::jsonb
   ) -> 'claims' ->> 'must_change_password'),
  'false',
  'an unflagged staff member does not'
);

-- The claim must never displace the role the app already routes on.
SELECT is(
  (public.custom_access_token_hook(
     '{"user_id":"11111111-1111-1111-1111-111111111111","claims":{}}'::jsonb
   ) -> 'claims' ->> 'user_role'),
  'driver',
  'user_role survives alongside the new claim'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run it to verify it fails**

Run: `supabase test db`
Expected: FAIL — the claim is absent, so the first two assertions return NULL.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0059_must_change_password_claim.sql`:

```sql
-- 0059_must_change_password_claim.sql
-- Extend custom_access_token_hook (0009, fixed in 0025, extended in 0043) with
-- a must_change_password claim.
--
-- A claim rather than a table read, because both apps' gates are synchronous:
-- the customer router's redirect cannot await, and the staff AuthGate decides
-- in initState. The staff app's Drift copy is empty on a first sign-in, which
-- is exactly the case a forced change has to serve.
--
-- It clears itself. Completing a set-password signs the user out, so the next
-- sign-in mints a token without the claim — the same mechanism that already
-- ends a recovery, and no cache to invalidate.
--
-- Stays SECURITY DEFINER with the existing restricted grants (CREATE OR REPLACE
-- preserves 0009's REVOKE/GRANT). Touches only custom claims, never the
-- reserved `role` claim (see 0025).

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  claims      jsonb;
  staff_role  text;
  is_customer boolean;
  resolved    text;
  must_change boolean;
  uid         uuid := (event->>'user_id')::uuid;
BEGIN
  SELECT role INTO staff_role FROM public.staff
   WHERE id = uid AND active = true;

  IF staff_role IS NOT NULL THEN
    resolved := staff_role;
    SELECT must_change_password INTO must_change FROM public.staff
     WHERE id = uid;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM public.customers
       WHERE auth_user_id = uid AND deleted_at IS NULL
    ) INTO is_customer;
    resolved := CASE WHEN is_customer THEN 'customer' ELSE 'none' END;
    SELECT must_change_password INTO must_change FROM public.customers
     WHERE auth_user_id = uid AND deleted_at IS NULL;
  END IF;

  claims := event->'claims';
  claims := jsonb_set(claims, '{user_role}', to_jsonb(resolved));
  claims := jsonb_set(claims, '{must_change_password}',
                      to_jsonb(COALESCE(must_change, false)));
  RETURN jsonb_set(event, '{claims}', claims);
END;
$$;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `supabase db reset && supabase test db`
Expected: the 3 `0059` assertions pass, and `0043`'s existing assertions still pass.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(db): emit must_change_password on the access token" -- supabase/migrations/0059_must_change_password_claim.sql supabase/tests/0059_must_change_password_claim_test.sql
```

---

## Task 5: Core reads the claim

**Files:**
- Modify: `packages/amuwak_core/lib/src/auth/session.dart`
- Test: `packages/amuwak_core/test/auth/session_test.dart`

**Interfaces:**
- Consumes: the claim from Task 4.
- Produces: `bool mustChangePasswordFromAccessToken(String? token)`; `mustChangePasswordProvider` (`Provider<bool>`).

- [ ] **Step 1: Write the failing test**

Append to `packages/amuwak_core/test/auth/session_test.dart`. Reuse the file's existing JWT-building helper if it has one; if not, add this alongside the tests:

```dart
  String _jwt(Map<String, dynamic> payload) {
    String seg(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${seg({'alg': 'HS256'})}.${seg(payload)}.sig';
  }

  group('mustChangePasswordFromAccessToken', () {
    final future = DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch ~/
        1000;

    test('is true when the claim says so', () {
      expect(
        mustChangePasswordFromAccessToken(
            _jwt({'must_change_password': true, 'exp': future})),
        isTrue,
      );
    });

    test('is false when the claim says so', () {
      expect(
        mustChangePasswordFromAccessToken(
            _jwt({'must_change_password': false, 'exp': future})),
        isFalse,
      );
    });

    test('is false for a token minted before the claim existed', () {
      // Must fail OPEN, not closed. A missing claim means an older token, not
      // a forced change — trapping every such user on a set-password screen
      // would be a self-inflicted outage.
      expect(mustChangePasswordFromAccessToken(_jwt({'exp': future})), isFalse);
    });

    test('is false for a malformed or absent token', () {
      expect(mustChangePasswordFromAccessToken(null), isFalse);
      expect(mustChangePasswordFromAccessToken('not-a-jwt'), isFalse);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/amuwak_core && flutter test test/auth/session_test.dart --timeout=none`
Expected: compile failure — `mustChangePasswordFromAccessToken` is not defined.

- [ ] **Step 3: Write the implementation**

In `session.dart`, below `roleFromAccessToken`:

```dart
/// Whether the signed-in user must set a new password before using the app.
///
/// Set when a manager issues a temporary password in person (see the
/// issue-temporary-password Edge Function), and cleared by the sign-out that
/// completing a set-password performs — the next token simply lacks it.
///
/// Fails OPEN: a missing claim means a token minted before 0059, not a forced
/// change. Defaulting to true would trap every existing session on the
/// set-password screen.
bool mustChangePasswordFromAccessToken(String? token) {
  final payload = _payloadOf(token);
  return payload?['must_change_password'] == true;
}

final mustChangePasswordProvider = Provider<bool>((ref) {
  final token = ref.watch(authStateProvider).valueOrNull?.session?.accessToken;
  return mustChangePasswordFromAccessToken(token);
});
```

`roleFromAccessToken` already contains the decode-and-expiry logic. Extract it into a shared private helper so both callers use one implementation — an expired token must yield no claim in both:

```dart
/// Decoded JWT payload, or null if the token is absent, malformed, or expired.
Map<String, dynamic>? _payloadOf(String? token) {
  if (token == null) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  final padded = parts[1] + '=' * ((4 - parts[1].length % 4) % 4);
  final Map<String, dynamic> payload;
  try {
    payload = jsonDecode(utf8.decode(base64Url.decode(padded)))
        as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final exp = payload['exp'];
  if (exp is int) {
    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    // Small clock-skew leeway so a device running slightly fast does not
    // reject an otherwise-valid token.
    const leeway = Duration(seconds: 30);
    if (DateTime.now().toUtc().isAfter(expiresAt.add(leeway))) return null;
  }
  return payload;
}
```

Then rewrite `roleFromAccessToken` to use it:

```dart
String? roleFromAccessToken(String? token) {
  final role = _payloadOf(token)?['user_role'];
  return role is String ? role : null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/amuwak_core && flutter test test/auth/session_test.dart --timeout=none`
Expected: PASS, including the pre-existing `roleFromAccessToken` tests — they are the regression check on the extraction.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(core): read must_change_password from the access token" -- packages/amuwak_core/lib/src/auth/session.dart packages/amuwak_core/test/auth/session_test.dart
```

---

## Task 6: Customer gate honours the flag

**Files:**
- Modify: `apps/amuwak_customer/lib/src/app/router.dart`
- Test: `apps/amuwak_customer/test/auth/router_redirect_test.dart`

**Interfaces:**
- Consumes: `mustChangePasswordProvider` from Task 5.
- Produces: `customerAuthRedirect({..., bool mustChangePassword = false})`.

- [ ] **Step 1: Write the failing test**

Append inside the `customerAuthRedirect` group:

```dart
    group('a password the customer did not choose', () {
      // A manager issued this password in person. It is known to someone else,
      // so the app is not usable until it is replaced.
      test('is replaced before anything else in the app', () {
        expect(
          customerAuthRedirect(
              signedIn: true,
              role: 'customer',
              mustChangePassword: true,
              location: '/'),
          kResetPasswordRoute,
        );
      });

      test('and the user is left there rather than looping', () {
        expect(
          customerAuthRedirect(
              signedIn: true,
              role: 'customer',
              mustChangePassword: true,
              location: kResetPasswordRoute),
          isNull,
        );
      });

      test('outranks finishing setup', () {
        expect(
          customerAuthRedirect(
              signedIn: true,
              role: 'none',
              mustChangePassword: true,
              location: '/'),
          kResetPasswordRoute,
        );
      });

      test('does not outrank being signed out', () {
        expect(
          customerAuthRedirect(
              signedIn: false, mustChangePassword: true, location: '/'),
          '/login',
        );
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/amuwak_customer && flutter test test/auth/router_redirect_test.dart --timeout=none`
Expected: compile failure — `The named parameter 'mustChangePassword' isn't defined`.

- [ ] **Step 3: Implement**

In `router.dart`, add the parameter and fold it into the existing recovery branch — both mean "set a password before going further", and they route to the same screen, so one branch serves both:

```dart
  bool recovering = false,
  bool recoveryLinkFailed = false,
  bool selfServiceReset = true,
  bool mustChangePassword = false,
}) {
```

then:

```dart
  if (recovering || mustChangePassword) {
    return location == kResetPasswordRoute ? null : kResetPasswordRoute;
  }
```

Extend the doc comment above the function:

```dart
/// [mustChangePassword] is the same demand from a different source: a manager
/// issued this password in person, so somebody else knows it. It shares the
/// recovery branch because the remedy is identical — set a new password before
/// anything else — and, like recovery, it does not outrank being signed out.
```

Wire it in `routerProvider`:

```dart
      mustChangePassword: ref.read(mustChangePasswordProvider),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/amuwak_customer && flutter test test/auth/router_redirect_test.dart --timeout=none`
Expected: PASS — 33 tests.

- [ ] **Step 5: Run the real-router regression**

Run: `cd apps/amuwak_customer && flutter test test/app/customer_app_test.dart --timeout=none`
Expected: PASS. `mustChangePasswordProvider` reads the overridden empty auth stream, yielding false.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(customer): force a password change when one was issued" -- apps/amuwak_customer/lib/src/app/router.dart apps/amuwak_customer/test/auth/router_redirect_test.dart
```

---

## Task 7: Staff gate honours the flag, and the dead Drift column goes

**Files:**
- Modify: `apps/amuwak_staff/lib/src/auth/auth_gate.dart`
- Modify: `apps/amuwak_staff/lib/src/data/tables/staff_table.dart`
- Modify: `apps/amuwak_staff/lib/src/data/app_database.dart`
- Modify: `apps/amuwak_staff/lib/src/sync/supabase_mappers.dart`
- Modify: `apps/amuwak_staff/lib/src/sync/sync_puller.dart`
- Test: `apps/amuwak_staff/test/auth/auth_gate_test.dart`
- Test: `apps/amuwak_staff/test/sync/supabase_mappers_test.dart`

**Interfaces:**
- Consumes: `mustChangePasswordProvider` from Task 5.
- Produces: nothing new.

The Drift column goes rather than getting renamed. Nothing reads it — the gate uses the claim — so a synced copy is pure liability: it would silently go stale against the renamed Postgres column and mislead whoever finds it.

- [ ] **Step 1: Write the failing gate test**

Append to `apps/amuwak_staff/test/auth/auth_gate_test.dart`:

```dart
  testWidgets('a password issued by a manager must be replaced on arrival',
      (tester) async {
    // Somebody else chose this password and said it out loud. The dashboard
    // is not reachable until it is replaced.
    await _pumpGate(tester, overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      currentAuthEventProvider.overrideWithValue(AuthChangeEvent.signedIn),
      mustChangePasswordProvider.overrideWithValue(true),
      authServiceProvider.overrideWithValue(_MockAuthService()),
      ..._dashboardStubs(),
    ]);

    expect(find.byType(SetPasswordScreen), findsOneWidget);
    expect(find.byType(StaffDashboardScreen), findsNothing);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/amuwak_staff && flutter test test/auth/auth_gate_test.dart --timeout=none`
Expected: FAIL — `Found 0 widgets with type "SetPasswordScreen"`; the gate shows the dashboard.

- [ ] **Step 3: Implement the gate change**

In `auth_gate.dart`'s `build`, after the `userId` null check:

```dart
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const LoginScreen();
    // A manager-issued password is known to someone else, so it is replaced
    // before anything else — the same demand as a recovery, from a different
    // source. Read from the token, not Drift: on a first sign-in the local
    // database is empty, which is exactly this case.
    if (_recovering || ref.watch(mustChangePasswordProvider)) {
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/amuwak_staff && flutter test test/auth/auth_gate_test.dart --timeout=none`
Expected: PASS — all 12 tests.

- [ ] **Step 5: Remove the dead Drift column**

In `staff_table.dart`, delete the `mustChangePin` column line.

In `supabase_mappers.dart:44`, delete the `mustChangePin:` argument.

In `sync_puller.dart:236`, delete the `mustChangePin: Value(...)` argument.

In `app_database.dart`, bump the schema version and add the migration step:

```dart
  int get schemaVersion => 9;
```

```dart
          if (from < 9) {
            // must_change_pin was never read by anything — it appeared only in
            // generated code. The forced-change flag now travels as an access
            // token claim, so a stale local copy is worse than none.
            await m.alterTable(TableMigration(staff));
          }
```

Regenerate: `cd apps/amuwak_staff && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Fix the tests that named the column**

`apps/amuwak_staff/test/auth/auth_gate_test.dart:28` and `apps/amuwak_staff/test/auth/set_password_screen_test.dart:25` construct `StaffData(... mustChangePin: false ...)`. Delete that argument from both.

`apps/amuwak_staff/test/sync/supabase_mappers_test.dart` asserts on it in two places — delete `expect(s.mustChangePin, isFalse);` and drop `mustChangePin` from the test's name and comment so the name still describes what it checks.

- [ ] **Step 7: Run the affected test files**

Run each separately:
`cd apps/amuwak_staff && flutter test test/auth/auth_gate_test.dart --timeout=none`
`cd apps/amuwak_staff && flutter test test/auth/set_password_screen_test.dart --timeout=none`
`cd apps/amuwak_staff && flutter test test/sync/supabase_mappers_test.dart --timeout=none`
`cd apps/amuwak_staff && flutter test test/app_database_test.dart --timeout=none`
Expected: PASS. The last covers the schema migration.

- [ ] **Step 8: Commit**

```bash
git commit -m "feat(staff): force a password change when one was issued" -- apps/amuwak_staff/lib apps/amuwak_staff/test
```

---

## Task 8: The `issue-temporary-password` Edge Function

**Files:**
- Create: `supabase/functions/issue-temporary-password/index.ts`

**Interfaces:**
- Consumes: `password_reset_audit` and both `must_change_password` columns (Task 3); `is_active_manager` (already shipped in `0055_min_two_managers.sql`).
- Produces: `POST /issue-temporary-password` with body `{ target_kind: 'staff' | 'customer', target_id: uuid }` → `200 { password: string }`.

There is no Deno test harness in this repo and `invite-staff` has none either, so this task's gate is the manual checklist in Step 3. Do not skip it.

- [ ] **Step 1: Write the function**

Create `supabase/functions/issue-temporary-password/index.ts`:

```ts
// issue-temporary-password
// -----------------------------------------------------------------------------
// Manager-only endpoint that sets a one-time password on a staff or customer
// account and returns it ONCE, for the manager to read aloud in person.
//
// This exists because no email can be delivered yet: see
// docs/superpowers/specs/2026-08-04-interim-account-recovery-design.md.
//
// Managers only, for EVERY target. For staff that is non-negotiable — a driver
// who could issue a manager's password turns one stolen rider phone into
// administrative takeover. For customers it is a deliberate tightening: a
// rider doing it is account takeover of a third party, and with no email the
// customer can never be told it happened.
//
// The generated password is never logged, never stored, and never emailed. It
// appears in exactly one place: this response body.

// Pinned to an exact version so a cold start cannot silently pull a different
// 2.x into a security-boundary function. Matches invite-staff.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const allowedOrigin = Deno.env.get('ALLOWED_ORIGIN') ?? '*';

const corsHeaders = {
  'Access-Control-Allow-Origin': allowedOrigin,
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Crockford-ish: no I, L, O, U, so nothing is misheard across a counter.
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const GROUPS = 3;
const GROUP_LEN = 4;

function generatePassword(): string {
  const bytes = new Uint8Array(GROUPS * GROUP_LEN);
  crypto.getRandomValues(bytes);
  const chars = Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]);
  const groups: string[] = [];
  for (let i = 0; i < GROUPS; i++) {
    groups.push(chars.slice(i * GROUP_LEN, (i + 1) * GROUP_LEN).join(''));
  }
  // 12 chars of a 32-symbol alphabet = 60 bits. Spent within the minute.
  return groups.join('-');
}

// An endpoint that can set any password is worth stealing a session for.
const MAX_PER_HOUR = 10;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // 1. Identify the caller from their bearer token.
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return json({ error: 'Missing authorization' }, 401);

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user: caller },
    error: callerErr,
  } = await callerClient.auth.getUser();
  if (callerErr || !caller) return json({ error: 'Not signed in' }, 401);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 2. The caller must be an active, not-soft-deleted MANAGER. This is the
  //    security boundary; the Flutter UI only hides the button.
  const { data: callerStaff } = await admin
    .from('staff')
    .select('role, active, deleted_at')
    .eq('id', caller.id)
    .maybeSingle();
  if (
    !callerStaff || callerStaff.active !== true ||
    callerStaff.deleted_at !== null || callerStaff.role !== 'manager'
  ) {
    return json({ error: 'Only managers can issue a password' }, 403);
  }

  // 3. The caller must not OWE an MFA challenge. A manager locked out at aal2
  //    still holds a valid aal1 session, so without this a stolen password
  //    alone is enough to strip access off any account. Fail CLOSED: an error
  //    listing factors must deny, never allow.
  const { data: factors, error: factorsErr } =
    await callerClient.auth.mfa.listFactors();
  if (factorsErr) {
    return json({ error: 'Could not verify your session' }, 403);
  }
  const hasVerifiedFactor = (factors?.totp ?? []).length > 0;
  if (hasVerifiedFactor) {
    const aal = (await callerClient.auth.mfa
      .getAuthenticatorAssuranceLevel()).data;
    if (aal?.currentLevel !== 'aal2') {
      return json({ error: 'Complete your 2FA challenge first' }, 403);
    }
  }

  // 4. Rate limit, read off the same audit table that records the abuse.
  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await admin
    .from('password_reset_audit')
    .select('id', { count: 'exact', head: true })
    .eq('actor_staff_id', caller.id)
    .gte('created_at', since);
  if ((count ?? 0) >= MAX_PER_HOUR) {
    return json({ error: 'Too many resets in the last hour' }, 429);
  }

  // 5. Validate the payload.
  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Invalid request body' }, 400);
  }
  const targetKind = String(payload.target_kind ?? '');
  const targetId = String(payload.target_id ?? '');
  if (targetKind !== 'staff' && targetKind !== 'customer') {
    return json({ error: 'Invalid target kind' }, 400);
  }
  if (!targetId) return json({ error: 'Target is required' }, 400);

  // 6. Resolve the target's auth user.
  let authUserId: string | null = null;
  if (targetKind === 'staff') {
    const { data: row } = await admin
      .from('staff')
      .select('id, deleted_at')
      .eq('id', targetId)
      .maybeSingle();
    if (!row || row.deleted_at !== null) {
      return json({ error: 'Staff member not found' }, 404);
    }
    authUserId = row.id; // staff.id IS the auth user id.
  } else {
    const { data: row } = await admin
      .from('customers')
      .select('auth_user_id, deleted_at')
      .eq('id', targetId)
      .maybeSingle();
    if (!row || row.deleted_at !== null) {
      return json({ error: 'Customer not found' }, 404);
    }
    if (!row.auth_user_id) {
      return json({ error: 'That customer has no account yet' }, 409);
    }
    authUserId = row.auth_user_id;
  }

  // 7. Set the password.
  const password = generatePassword();
  const { error: updateErr } = await admin.auth.admin.updateUserById(
    authUserId!,
    { password },
  );
  if (updateErr) {
    // Deliberately not logging updateErr verbatim — it can echo the payload.
    console.error('issue-temporary-password: update failed', {
      targetKind,
      targetId,
    });
    return json({ error: 'Could not set the password' }, 502);
  }

  // 8. Flag the forced change. After the password, so a failure above leaves
  //    the account untouched rather than flagged for a change that never came.
  const flagTable = targetKind === 'staff' ? 'staff' : 'customers';
  const { error: flagErr } = await admin
    .from(flagTable)
    .update({ must_change_password: true })
    .eq('id', targetId);
  if (flagErr) {
    console.error('issue-temporary-password: flag failed', {
      targetKind,
      targetId,
    });
    return json({ error: 'Could not set the password' }, 502);
  }

  // 9. Audit. Non-fatal only in the sense that the password already changed —
  //    log loudly, because an unaudited issuance is the thing this table
  //    exists to prevent.
  const { error: auditErr } = await admin.from('password_reset_audit').insert({
    actor_staff_id: caller.id,
    target_kind: targetKind,
    target_id: targetId,
  });
  if (auditErr) {
    console.error('issue-temporary-password: AUDIT WRITE FAILED', {
      actor: caller.id,
      targetKind,
      targetId,
      error: auditErr.message,
    });
  }

  return json({ password }, 200);
});
```

- [ ] **Step 2: Deploy in the right order**

```bash
supabase db push          # 0058 and 0059 FIRST
supabase functions deploy issue-temporary-password
```

The function before its audit table means every issuance is silently unaudited. That is the lesson from #106; do not reorder these.

- [ ] **Step 3: Work the manual checklist**

Record each result in the PR description. Checks 1 and 2 are **not optional** — they are the security boundary.

1. **A driver cannot issue anything.** Sign in as a driver, call the function for a customer target. Expect 403. Repeat for a staff target. Expect 403.
2. **An `in_shop` member cannot issue anything.** Same two calls. Expect 403 both times.
3. **A soft-deleted manager cannot issue.** Set `deleted_at` on a manager, call. Expect 403.
4. **A manager can issue for a customer.** Expect 200 and a `4K7M-9PQR-2XTY`-shaped password.
5. **A manager can issue for a staff member.** Expect 200.
6. **An unknown target 404s**, and a customer with no `auth_user_id` 409s.
7. **The audit row exists** with the right actor, kind and target after checks 4 and 5.
8. **The issued password works once**, and the recipient lands on the set-password screen rather than the app.
9. **After they set a new password**, signing in again goes straight to the app — the claim is gone.
10. **The rate limit trips** on the 11th issuance within an hour. Expect 429.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(functions): manager-issued one-time passwords" -- supabase/functions/issue-temporary-password/index.ts
```

---

## Task 9: Staff app issues and reveals the password

**Files:**
- Create: `apps/amuwak_staff/lib/src/staff/issue_temporary_password_service.dart`
- Create: `apps/amuwak_staff/test/staff/issue_temporary_password_service_test.dart`

**Interfaces:**
- Consumes: the Edge Function from Task 8.
- Produces: `IssueTemporaryPasswordService.issue({required String targetKind, required String targetId}) → Future<String>`; `IssueTemporaryPasswordFn` typedef; `IssuePasswordFailure`.

Mirrors `InviteStaffService` exactly — same typedef-plus-service shape, so the screen can be tested with a plain function.

- [ ] **Step 1: Write the failing test**

Create `apps/amuwak_staff/test/staff/issue_temporary_password_service_test.dart`:

```dart
import 'package:amuwak_staff/src/staff/issue_temporary_password_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  late _MockClient client;
  late _MockFunctions functions;
  late IssueTemporaryPasswordService service;

  setUp(() {
    client = _MockClient();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
    service = IssueTemporaryPasswordService(client);
  });

  test('returns the password the server generated', () async {
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
      (_) async => FunctionResponse(
          data: {'password': '4K7M-9PQR-2XTY'}, status: 200),
    );

    final password =
        await service.issue(targetKind: 'customer', targetId: 'cust-1');

    expect(password, '4K7M-9PQR-2XTY');
    verify(() => functions.invoke('issue-temporary-password',
        body: {'target_kind': 'customer', 'target_id': 'cust-1'})).called(1);
  });

  test('surfaces the server refusal rather than a blank failure', () async {
    // A non-manager gets 403 here. The message is the whole point — a silent
    // failure looks identical to a network problem.
    //
    // thenThrow, not thenAnswer: invoke() throws FunctionException on a
    // non-2xx, it does not return one. Mocking it as a return value would
    // assert a contract the SDK does not have, and would pass against a
    // service that mishandles every real refusal.
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
      FunctionException(
        status: 403,
        details: {'error': 'Only managers can issue a password'},
      ),
    );

    await expectLater(
      service.issue(targetKind: 'staff', targetId: 'staff-1'),
      throwsA(isA<IssuePasswordFailure>().having(
        (e) => e.message,
        'message',
        'Only managers can issue a password',
      )),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/amuwak_staff && flutter test test/staff/issue_temporary_password_service_test.dart --timeout=none`
Expected: compile failure — the library does not exist.

- [ ] **Step 3: Write the implementation**

Create `apps/amuwak_staff/lib/src/staff/issue_temporary_password_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Callback shape the issuing UI depends on, so a screen can be tested with a
/// plain function. Mirrors [InviteStaffFn].
typedef IssueTemporaryPasswordFn = Future<String> Function({
  required String targetKind,
  required String targetId,
});

/// Raised when a password cannot be issued — the caller is not a manager, owes
/// an MFA challenge, has hit the hourly limit, or the target does not exist.
/// Carries the server's message, because "it failed" is indistinguishable from
/// a dead network to whoever is standing at the counter.
class IssuePasswordFailure implements Exception {
  IssuePasswordFailure(this.message);
  final String message;
  @override
  String toString() => 'IssuePasswordFailure: $message';
}

/// Issues a one-time password by calling the `issue-temporary-password` Edge
/// Function, which runs with the service-role key and enforces manager-only
/// access server-side. Nothing privileged happens in the client.
///
/// The returned password exists in exactly one place — the response — and must
/// be shown once and never persisted.
class IssueTemporaryPasswordService {
  IssueTemporaryPasswordService(this._client);

  final SupabaseClient _client;

  Future<String> issue({
    required String targetKind,
    required String targetId,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'issue-temporary-password',
        body: {'target_kind': targetKind, 'target_id': targetId},
      );
    } on FunctionException catch (e) {
      // invoke() THROWS on any non-2xx rather than returning it, so this is
      // the only path a refusal takes — there is no `response.status != 200`
      // branch to reach. Getting this wrong is not cosmetic: the 403 a
      // non-manager gets would fall to the generic catch below and be reported
      // as an unreachable server, which is exactly the "indistinguishable from
      // a dead network" failure this class exists to avoid.
      throw IssuePasswordFailure(_messageFrom(e));
    } catch (_) {
      throw IssuePasswordFailure('Could not reach the server. Try again.');
    }

    // Validated outside the try: an IssuePasswordFailure thrown inside it
    // would be swallowed by the generic catch and relabelled a network error.
    final data = response.data;
    final password = data is Map ? data['password'] : null;
    if (password is! String || password.isEmpty) {
      throw IssuePasswordFailure('Could not issue a password.');
    }
    return password;
  }

  /// Pulls the server's `{ "error": "..." }` body out of a FunctionException so
  /// the manager sees the real reason rather than a bare status code. Mirrors
  /// `ResetStaffMfaService._messageFrom`.
  static String _messageFrom(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.isNotEmpty) return details;
    return 'Could not issue a password.';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/amuwak_staff && flutter test test/staff/issue_temporary_password_service_test.dart --timeout=none`
Expected: PASS — 2 tests.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(staff): client for manager-issued one-time passwords" -- apps/amuwak_staff/lib/src/staff/issue_temporary_password_service.dart apps/amuwak_staff/test/staff/issue_temporary_password_service_test.dart
```

---

## Task 10: The issuing screen

**Files:**
- Create: `apps/amuwak_staff/lib/src/staff/issue_password_screen.dart`
- Test: `apps/amuwak_staff/test/staff/issue_password_screen_test.dart`

**Interfaces:**
- Consumes: `IssueTemporaryPasswordFn` from Task 9.
- Produces: `IssuePasswordScreen({required IssueTemporaryPasswordFn onIssue, required String targetKind, required String targetId, required String targetLabel})`.

**Why the screen takes a target rather than finding one.** The staff app has **no staff-list or customer-list screen** — only `invite_staff_screen.dart`. Building a directory is a bigger piece of work than this plan should absorb, and it needs its own decisions about search. So this screen is a leaf: it receives a target and issues for it. Wire it from wherever a manager already has a customer or staff member in hand (order details shows a customer). A picker is a follow-up.

Both `customers` and `staff` are already synced into the staff app's Drift DB, so a picker is buildable later without new sync work.

- [ ] **Step 1: Write the failing test**

Create `apps/amuwak_staff/test/staff/issue_password_screen_test.dart`:

```dart
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/staff/issue_password_screen.dart';
import 'package:amuwak_staff/src/staff/issue_temporary_password_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(IssueTemporaryPasswordFn onIssue) => ProviderScope(
      child: MaterialApp(
        theme: buildAmuwakTheme(),
        home: IssuePasswordScreen(
          onIssue: onIssue,
          targetKind: 'customer',
          targetId: 'cust-1',
          targetLabel: 'Ada Byron',
        ),
      ),
    );

void main() {
  testWidgets('shows the issued password for the manager to read out',
      (tester) async {
    await tester.pumpWidget(_harness(
        ({required targetKind, required targetId}) async => '4K7M-9PQR-2XTY'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Issue a temporary password'));
    await tester.pumpAndSettle();

    expect(find.text('4K7M-9PQR-2XTY'), findsOneWidget);
  });

  testWidgets('warns that the password is shown only once', (tester) async {
    // It exists in exactly one place — this screen. A manager who dismisses it
    // without reading it out has to issue another and spend the audit entry.
    await tester.pumpWidget(_harness(
        ({required targetKind, required targetId}) async => '4K7M-9PQR-2XTY'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Issue a temporary password'));
    await tester.pumpAndSettle();

    expect(find.textContaining('once'), findsWidgets);
  });

  testWidgets('surfaces a refusal instead of failing silently', (tester) async {
    await tester.pumpWidget(_harness(
        ({required targetKind, required targetId}) async =>
            throw IssuePasswordFailure('Only managers can issue a password')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Issue a temporary password'));
    await tester.pumpAndSettle();

    expect(find.text('Only managers can issue a password'), findsOneWidget);
  });

  testWidgets('asks before issuing, since it invalidates the old password',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_harness(({required targetKind, required targetId}) async {
      calls++;
      return '4K7M-9PQR-2XTY';
    }));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/amuwak_staff && flutter test test/staff/issue_password_screen_test.dart --timeout=none`
Expected: compile failure — `issue_password_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `apps/amuwak_staff/lib/src/staff/issue_password_screen.dart`:

```dart
import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'issue_temporary_password_service.dart';

/// Issues a one-time password for one account and shows it once.
///
/// Deliberately a leaf that receives its target: the staff app has no
/// directory to pick from, and building one is a separate job.
///
/// The password is held in widget state and nowhere else — not persisted, not
/// logged, not copied to a field that survives the route. Losing it costs an
/// audit entry and another issuance, which is the right trade against leaving
/// a live credential lying around in storage.
class IssuePasswordScreen extends ConsumerStatefulWidget {
  const IssuePasswordScreen({
    super.key,
    required this.onIssue,
    required this.targetKind,
    required this.targetId,
    required this.targetLabel,
  });

  final IssueTemporaryPasswordFn onIssue;
  final String targetKind;
  final String targetId;
  final String targetLabel;

  @override
  ConsumerState<IssuePasswordScreen> createState() =>
      _IssuePasswordScreenState();
}

class _IssuePasswordScreenState extends ConsumerState<IssuePasswordScreen> {
  bool _busy = false;
  String? _password;
  String? _error;

  Future<void> _issue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final password = await widget.onIssue(
        targetKind: widget.targetKind,
        targetId: widget.targetId,
      );
      if (mounted) setState(() => _password = password);
    } on IssuePasswordFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not issue a password. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Temporary password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.targetLabel, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'They will be asked to choose their own password as soon as '
                'they sign in. Their current one stops working immediately.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_password == null) ...[
                if (_error != null) ...[
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: AppSpacing.md),
                ],
                FilledButton(
                  onPressed: _busy ? null : _issue,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Issue a temporary password'),
                ),
              ] else ...[
                Text('Read this out to them now',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  _password!,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontFeatures: const [
                    FontFeature.tabularFigures(),
                  ]),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Shown once. Leaving this screen loses it, and you would '
                  'have to issue another.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

Add `import 'dart:ui' show FontFeature;` at the top.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/amuwak_staff && flutter test test/staff/issue_password_screen_test.dart --timeout=none`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(staff): screen that issues and reveals a temporary password" -- apps/amuwak_staff/lib/src/staff/issue_password_screen.dart apps/amuwak_staff/test/staff/issue_password_screen_test.dart
```

---

## Task 11: Full verification and PR

- [ ] **Step 1: Analyze every package**

```bash
cd packages/amuwak_core && flutter analyze
cd ../../apps/amuwak_customer && flutter analyze
cd ../amuwak_staff && flutter analyze
```

Expected: `No issues found!` in all three. Read the log rather than trusting an exit code from a pipeline.

- [ ] **Step 2: Run all three suites**

```bash
cd packages/amuwak_core && flutter test --timeout=none
cd ../../apps/amuwak_customer && flutter test --timeout=none
cd ../amuwak_staff && flutter test --timeout=none
```

Expected: all green. Baselines before this plan: core 204, customer 137, staff 864 passed / 12 skipped. This plan adds roughly 6 to core, 8 to customer and 7 to staff.

- [ ] **Step 3: Run pgTAP**

```bash
supabase start -x storage-api,imgproxy --ignore-health-check
supabase db reset && supabase test db
```

Expected: the `0058` and `0059` assertions pass. `0015_powersync` fails 15/15 and always has — a non-zero exit is only your regression if a `0058`/`0059` assertion is among the failures.

- [ ] **Step 4: Open the PR**

Base it on whatever of the #104 → #107 → #108 → #109 stack has not yet merged. In the description, include the completed manual checklist from Task 8 Step 3 and the findings from Task 0 Step 5 — a reviewer cannot re-run either.

State plainly what is still missing: without email nobody can be *told* their password was reset, so the audit table is the only control and it is after the fact.
