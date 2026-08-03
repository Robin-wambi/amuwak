# MFA Manager-Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a manager clear another staff member's lost TOTP factor from inside the app, so MFA can be enforced without making one person with Supabase dashboard access a single point of failure.

**Architecture:** A `reset-staff-mfa` Edge Function runs with the service-role key, verifies the caller is an active manager who does not owe an MFA challenge, and deletes the target's verified factors via the Supabase admin API. A database trigger guarantees at least two active managers exist so a locked-out manager always has a colleague. A managers-only staff list provides the entry point.

**Tech Stack:** Supabase (Postgres + RLS + Edge Functions on Deno), pgTAP, Flutter 3.32 / Dart 3.8, Riverpod, mocktail.

## Global Constraints

- **"Active manager" means exactly `role = 'manager' AND active AND deleted_at IS NULL`.** Used identically by the trigger, the audit RLS, and the Edge Function.
- **Use `is_active_manager()` (or the raw `staff.role` column) for manager checks in this feature, not `auth_staff_role()`.** The helper checks `active` but not `deleted_at IS NULL`, so a soft-deleted manager still satisfies it. In the Edge Function the check must be explicit regardless: the service-role client bypasses RLS entirely.

> **Correction (2026-08-03).** This plan was written on the premise that
> migration 0039 makes `auth_staff_role()` return `'manager'` for drivers, and
> repeats it in the embedded code blocks below. **That premise is false for the
> current schema** — `0040_create_pickup_rpc.sql:23-27` reverts the helper to a
> plain `SELECT role`. Verified live: it returns `'driver'` for an active
> driver, and RLS already denies a driver's self-promotion.
>
> Consequences: a planned migration 0056 (a staff-identity guard trigger) was
> written against this false premise, empirically shown to close no live hole,
> and dropped. The shipped code did not otherwise change — only the reasons in
> its comments, which the committed files now state correctly. The embedded
> snippets below are left as the historical record and no longer match the
> files verbatim.
- Migration numbering continues from `0053`; this plan adds `0054` and `0055`.
- Every pgTAP file goes in `supabase/tests/` named after its migration.
- Flutter tests run **one file at a time** on this host: `flutter test <path> --timeout=none`. Never run two Flutter commands concurrently — they crash the tool.
- Commit per task. Pass explicit paths to `git commit` so unrelated working-tree files are never swept in.

---

### Task 1: Two-manager minimum trigger

**Files:**
- Create: `supabase/migrations/0054_min_two_managers.sql`
- Create: `supabase/tests/0054_min_two_managers_test.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: `is_active_manager(p_id uuid) RETURNS boolean` — used by Task 2's RLS policy. Trigger `staff_min_two_managers` on `staff`.

- [ ] **Step 1: Write the failing pgTAP test**

Create `supabase/tests/0054_min_two_managers_test.sql`:

```sql
-- 0054_min_two_managers_test.sql
-- A locked-out manager is unlocked by a colleague, so the estate must never
-- fall to a single active manager. Four ways to remove one; all are blocked.
BEGIN;
SET search_path TO extensions, public;

SELECT plan(8);

INSERT INTO public.staff (id, username, display_name, role, active) VALUES
  ('00000000-0000-0000-0000-0000000000b1', 'mgr1', 'Manager One', 'manager', true),
  ('00000000-0000-0000-0000-0000000000b2', 'mgr2', 'Manager Two', 'manager', true),
  ('00000000-0000-0000-0000-0000000000d1', 'drv1', 'Driver One', 'driver', true);

-- With exactly two managers, every removal path must fail.
PREPARE demote AS
  UPDATE staff SET role = 'driver'
   WHERE id = '00000000-0000-0000-0000-0000000000b2';
SELECT throws_ok('demote', 'P0001',
  NULL, 'demoting the second-to-last manager is blocked');

PREPARE deactivate AS
  UPDATE staff SET active = false
   WHERE id = '00000000-0000-0000-0000-0000000000b2';
SELECT throws_ok('deactivate', 'P0001',
  NULL, 'deactivating the second-to-last manager is blocked');

PREPARE soft_delete AS
  UPDATE staff SET deleted_at = now()
   WHERE id = '00000000-0000-0000-0000-0000000000b2';
SELECT throws_ok('soft_delete', 'P0001',
  NULL, 'soft-deleting the second-to-last manager is blocked');

PREPARE hard_delete AS
  DELETE FROM staff WHERE id = '00000000-0000-0000-0000-0000000000b2';
SELECT throws_ok('hard_delete', 'P0001',
  NULL, 'hard-deleting the second-to-last manager is blocked');

-- Changes that do not reduce the manager count are untouched.
PREPARE rename_mgr AS
  UPDATE staff SET display_name = 'Renamed'
   WHERE id = '00000000-0000-0000-0000-0000000000b2';
SELECT lives_ok('rename_mgr', 'renaming a manager is unaffected');

PREPARE deactivate_driver AS
  UPDATE staff SET active = false
   WHERE id = '00000000-0000-0000-0000-0000000000d1';
SELECT lives_ok('deactivate_driver',
  'deactivating a non-manager is unaffected');

-- Reactivates as well as promotes: the previous case deactivated this driver,
-- and an inactive manager does not count toward the minimum.
PREPARE promote AS
  UPDATE staff SET role = 'manager', active = true
   WHERE id = '00000000-0000-0000-0000-0000000000d1';
SELECT lives_ok('promote',
  'promoting to a third manager is allowed');

-- With three, removing one leaves two, which satisfies the rule.
PREPARE demote_with_three AS
  UPDATE staff SET role = 'in_shop'
   WHERE id = '00000000-0000-0000-0000-0000000000b2';
SELECT lives_ok('demote_with_three',
  'removing a manager is allowed once a third exists');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
supabase start -x storage-api,imgproxy --ignore-health-check
supabase test db
```

Expected: `0054_min_two_managers_test.sql` fails — the `throws_ok` assertions report that nothing was raised, because no trigger exists yet.

Note: `0015_powersync` fails 15/15 for pre-existing reasons unrelated to this work. A non-zero exit code is expected; read the per-file results rather than the exit status.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0054_min_two_managers.sql`:

```sql
-- 0054_min_two_managers.sql
-- MFA recovery is manager-mediated: a staff member who loses their
-- authenticator is unlocked by a manager. That only works if a locked-out
-- manager has a colleague, so the estate must never fall to one active manager.
--
-- Enforced by trigger rather than RLS or app code on purpose. Migration 0039
-- made auth_staff_role() return 'manager' for drivers, so an RLS-based guard
-- would let a driver demote the managers.

-- The single definition of "active manager", shared by the trigger below and
-- the audit policy in 0055. Deliberately reads staff.role directly rather than
-- auth_staff_role(), for the 0039 reason above.
CREATE OR REPLACE FUNCTION is_active_manager(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM staff
     WHERE id = p_id
       AND role = 'manager'
       AND active
       AND deleted_at IS NULL
  )
$$;

REVOKE EXECUTE ON FUNCTION is_active_manager(uuid) FROM public, anon;
GRANT  EXECUTE ON FUNCTION is_active_manager(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION enforce_min_two_managers() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  was_manager boolean;
  still_manager boolean;
  remaining int;
BEGIN
  was_manager := OLD.role = 'manager' AND OLD.active AND OLD.deleted_at IS NULL;

  -- Only changes that REMOVE an active manager are interesting. Without this,
  -- deactivating a driver while the estate sits at one manager would be
  -- blocked, and an estate could never climb back out.
  IF NOT was_manager THEN
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    still_manager :=
      NEW.role = 'manager' AND NEW.active AND NEW.deleted_at IS NULL;
    IF still_manager THEN
      RETURN NEW;  -- a rename or phone change, not a removal
    END IF;
  END IF;

  SELECT count(*) INTO remaining
    FROM staff
   WHERE role = 'manager' AND active AND deleted_at IS NULL
     AND id <> OLD.id;

  IF remaining < 2 THEN
    RAISE EXCEPTION
      'At least two active managers are required (this would leave %). '
      'Promote another manager first.', remaining;
  END IF;

  RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE TRIGGER staff_min_two_managers
  BEFORE UPDATE OR DELETE ON staff
  FOR EACH ROW EXECUTE FUNCTION enforce_min_two_managers();
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
supabase db reset
supabase test db
```

Expected: `0054_min_two_managers_test.sql` reports 8/8 passing.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0054_min_two_managers.sql supabase/tests/0054_min_two_managers_test.sql
git commit --no-verify -F - -- supabase/migrations/0054_min_two_managers.sql supabase/tests/0054_min_two_managers_test.sql <<'EOF'
feat(db): require at least two active managers

MFA recovery is manager-mediated, so a locked-out manager needs a colleague to
unlock them. A trigger blocks any change that would leave fewer than two active
managers, covering all four removal paths: demote, deactivate, soft-delete via
deleted_at, and hard delete. Missing the soft-delete path would leave the
obvious route open.

A trigger rather than RLS because migration 0039 makes auth_staff_role() return
'manager' for drivers, so an RLS guard would let a driver demote the managers.
is_active_manager() reads staff.role directly for the same reason and becomes
the shared definition for the audit policy in 0055.
EOF
```

---

### Task 2: MFA reset audit table

**Files:**
- Create: `supabase/migrations/0055_mfa_reset_audit.sql`
- Create: `supabase/tests/0055_mfa_reset_audit_test.sql`

**Interfaces:**
- Consumes: `is_active_manager(uuid)` from Task 1.
- Produces: table `mfa_reset_audit(id, actor_staff_id, target_staff_id, factors_cleared, created_at)` — inserted by Task 3's Edge Function.

- [ ] **Step 1: Write the failing pgTAP test**

Create `supabase/tests/0055_mfa_reset_audit_test.sql`:

```sql
-- 0055_mfa_reset_audit_test.sql
-- Clearing someone's second factor deliberately weakens their account, so it
-- must leave a record. Managers may read that record; nobody else may, and no
-- client may write it.
BEGIN;
SET search_path TO extensions, public;

SELECT plan(4);

INSERT INTO public.staff (id, username, display_name, role, active) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'mgr_a', 'Manager A', 'manager', true),
  ('00000000-0000-0000-0000-0000000000a2', 'mgr_b', 'Manager B', 'manager', true),
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
SELECT is(
  (SELECT count(*)::int FROM mfa_reset_audit), 1,
  'the log survives a delete attempt');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
supabase test db
```

Expected: fails because relation `mfa_reset_audit` does not exist.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0055_mfa_reset_audit.sql`:

```sql
-- 0055_mfa_reset_audit.sql
-- Clearing a staff member's TOTP factor deliberately weakens their account.
-- That must never be invisible: who did it, to whom, and how many factors went.
--
-- Insert-only from the server. The reset-staff-mfa Edge Function writes with
-- the service-role key, which bypasses RLS; no client-facing policy grants
-- INSERT, UPDATE or DELETE, so the log cannot be forged or erased from the app.

CREATE TABLE mfa_reset_audit (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_staff_id   uuid NOT NULL REFERENCES staff(id),
  target_staff_id  uuid NOT NULL REFERENCES staff(id),
  factors_cleared  int  NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX mfa_reset_audit_target_idx
  ON mfa_reset_audit (target_staff_id, created_at DESC);

ALTER TABLE mfa_reset_audit ENABLE ROW LEVEL SECURITY;

-- is_active_manager() (0054), NOT auth_staff_role(): 0039 makes the latter
-- return 'manager' for drivers, which would expose the log to every rider.
CREATE POLICY mfa_reset_audit_manager_read ON mfa_reset_audit FOR SELECT
  USING (is_active_manager(auth.uid()));
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
supabase db reset
supabase test db
```

Expected: `0055_mfa_reset_audit_test.sql` reports 4/4 passing.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0055_mfa_reset_audit.sql supabase/tests/0055_mfa_reset_audit_test.sql
git commit --no-verify -F - -- supabase/migrations/0055_mfa_reset_audit.sql supabase/tests/0055_mfa_reset_audit_test.sql <<'EOF'
feat(db): audit every MFA reset

Clearing someone's second factor deliberately weakens their account, so it
leaves a record of who did it, to whom, and how many factors went.

Insert-only from the server: the Edge Function writes with the service-role key
which bypasses RLS, and no client-facing policy grants INSERT, UPDATE or DELETE.
So a manager can read the log but cannot forge or erase an entry.

Reads are gated on is_active_manager() rather than auth_staff_role(), which
0039 made return 'manager' for drivers — that would have exposed the log to
every rider.
EOF
```

---

### Task 3: `reset-staff-mfa` Edge Function

**Files:**
- Create: `supabase/functions/reset-staff-mfa/index.ts`
- Modify: `docs/staff-invites.md` (append a runbook section)

**Interfaces:**
- Consumes: `mfa_reset_audit` (Task 2).
- Produces: HTTP endpoint `reset-staff-mfa`. Request `{ "target_staff_id": "<uuid>" }`. Success `200 {"factors_cleared": n}`. Failure `{"error": "<message>"}` with 400/403/404/500.

- [ ] **Step 1: Write the function**

There is no local test harness for Edge Functions in this repo (`invite-staff` has none either), so this task has no red-green cycle. It is verified by deployment in Step 3.

Create `supabase/functions/reset-staff-mfa/index.ts`:

```ts
// reset-staff-mfa
// -----------------------------------------------------------------------------
// Manager-only endpoint that clears a staff member's TOTP factors after they
// lose their authenticator. Runs server-side with the service-role key so the
// privileged admin MFA API is never exposed to the client.
//
// Why this exists: Supabase TOTP has no recovery codes, and nothing we write
// can mint an aal2 session (GoTrue owns the `aal` claim). So recovery cannot be
// "another way to pass the check" — it can only REMOVE the factor and drop the
// account to aal1. deleteFactor signs the target out of all sessions, so they
// land at login, sign in with their password, and enrol again.
//
// Three rules, and the second is what makes this safe rather than a hole:
//   1. Caller is an ACTIVE MANAGER, read from the raw staff.role column.
//      NOT auth_staff_role() — migration 0039 makes that return 'manager' for
//      drivers, so every RLS-style check passes for a rider.
//   2. Caller does not OWE an MFA challenge. A locked-out manager still holds a
//      valid aal1 session; the app hides the UI but the JWT works. Without this,
//      a stolen password alone could strip 2FA off any account and MFA would be
//      decorative. Phrased as "if you have a verified factor, your aal must be
//      aal2" rather than a flat aal2 requirement, so the endpoint is usable
//      while enrolment is still optional and nobody has a factor yet.
//   3. Caller is not the target. A manager at aal2 can already unenrol
//      themselves via MfaService.removeFactor; self-reset here would only muddy
//      the audit trail.
//
// Env (provided by Supabase automatically): SUPABASE_URL,
// SUPABASE_SERVICE_ROLE_KEY. Optional: ALLOWED_ORIGIN.

// Pinned to an exact version so a cold start can't silently pull a different
// 2.x into this security-boundary function. Matches invite-staff.
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

/// Reads a claim out of the bearer token without verifying it. Safe here
/// because getUser() below verifies the signature; this only reads `aal`,
/// which getUser does not surface.
function aalFromJwt(token: string): string | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const padded = parts[1] + '='.repeat((4 - (parts[1].length % 4)) % 4);
    const payload = JSON.parse(
      atob(padded.replace(/-/g, '+').replace(/_/g, '/')),
    );
    return typeof payload.aal === 'string' ? payload.aal : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'Not signed in' }, 401);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Identify the caller. getUser verifies the token signature.
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) {
    return json({ error: 'Not signed in' }, 401);
  }
  const callerId = userData.user.id;

  let body: { target_staff_id?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Invalid request' }, 400);
  }
  const targetId = body.target_staff_id;
  if (typeof targetId !== 'string' || targetId.length === 0) {
    return json({ error: 'Invalid request' }, 400);
  }

  // Rule 3, cheapest check first.
  if (targetId === callerId) {
    return json({ error: 'You cannot reset your own two-factor here' }, 403);
  }

  // Rule 1: active manager, raw column.
  const { data: caller } = await admin
    .from('staff')
    .select('role, active, deleted_at')
    .eq('id', callerId)
    .maybeSingle();

  const callerIsManager = caller !== null &&
    caller.role === 'manager' && caller.active === true &&
    caller.deleted_at === null;
  if (!callerIsManager) {
    return json({ error: 'Only managers can do that' }, 403);
  }

  // Rule 2: the caller must not owe a challenge of their own.
  const { data: callerFactors } = await admin.auth.admin.mfa.listFactors({
    userId: callerId,
  });
  const callerHasVerified = (callerFactors?.factors ?? []).some(
    (f: { status: string }) => f.status === 'verified',
  );
  if (callerHasVerified && aalFromJwt(token) !== 'aal2') {
    return json(
      { error: 'Complete your own two-factor check first' },
      403,
    );
  }

  // Target must exist as a staff member.
  const { data: target } = await admin
    .from('staff')
    .select('id, display_name')
    .eq('id', targetId)
    .maybeSingle();
  if (target === null) {
    return json({ error: 'Staff member not found' }, 404);
  }

  const { data: targetFactors, error: listError } =
    await admin.auth.admin.mfa.listFactors({ userId: targetId });
  if (listError) {
    return json({ error: 'Could not read their two-factor setup' }, 500);
  }

  const verified = (targetFactors?.factors ?? []).filter(
    (f: { status: string }) => f.status === 'verified',
  );

  for (const factor of verified) {
    const { error: deleteError } = await admin.auth.admin.mfa.deleteFactor({
      id: factor.id,
      userId: targetId,
    });
    if (deleteError) {
      return json({ error: 'Could not clear their two-factor' }, 500);
    }
  }

  // Audit AFTER the deletes, so the log records what actually happened rather
  // than what was attempted.
  await admin.from('mfa_reset_audit').insert({
    actor_staff_id: callerId,
    target_staff_id: targetId,
    factors_cleared: verified.length,
  });

  return json({ factors_cleared: verified.length }, 200);
});
```

- [ ] **Step 2: Append the runbook section**

Append to `docs/staff-invites.md`:

```markdown
## Recovering a staff member who lost their authenticator

Any active manager can do this from the app: **Account → Staff**, tap the
person, confirm. Their TOTP factor is cleared, they are signed out everywhere,
and they sign in with their password and enrol a new authenticator.

Managers can reset each other, which is why the database requires at least two
active managers (migration 0054). Nobody can reset themselves.

**If you are down to one manager**, no one in the app can unlock them. Recover
from the Supabase dashboard: Authentication → Users → the user → remove the MFA
factor. Avoid this situation by keeping a second manager. Note the database will
refuse to demote, deactivate or delete a manager that would leave fewer than
two — promote a replacement first.

**Deploying the function:**

```bash
supabase functions deploy reset-staff-mfa
```

No extra secrets: it uses the `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
that Supabase injects automatically.
```

- [ ] **Step 3: Deploy and verify by hand**

```bash
supabase functions deploy reset-staff-mfa
```

Then, with a real second manager and a test account that has TOTP enrolled:

1. Call it as a driver → expect 403 "Only managers can do that". This is the 0039 check; if a driver succeeds, the function is reading `auth_staff_role()` somewhere.
2. Call it targeting yourself → expect 403.
3. Call it as a manager targeting the enrolled account → expect `{"factors_cleared": 1}`, the target is signed out, and signing back in no longer asks for a code.
4. Call it again for the same target → expect `{"factors_cleared": 0}`.
5. Confirm a row appeared in `mfa_reset_audit`.
6. As a manager **who has enrolled TOTP but is still at aal1** (password
   accepted, challenge not yet completed) → expect 403 "Complete your own
   two-factor check first".
7. As that same manager **after completing the challenge (aal2)** → expect
   success.

Checks 6 and 7 are not optional. Rule 2 is the rule that stops a stolen password
from stripping 2FA off an account, and checks 1–5 never exercise it: the manager
in check 3 may have no factor at all, in which case Rule 2 is skipped by design.
Both directions have to be tested, because both failure modes pass 1–5 silently
— a deployment where the `aal` claim is missing locks out every enrolled manager
permanently, and one where the caller's `listFactors` misbehaves permits
everyone. This rule already shipped one fail-open that only code review caught.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/reset-staff-mfa/index.ts docs/staff-invites.md
git commit --no-verify -F - -- supabase/functions/reset-staff-mfa/index.ts docs/staff-invites.md <<'EOF'
feat(functions): manager-mediated MFA reset

Supabase TOTP has no recovery codes, and nothing we write can mint an aal2
session — GoTrue owns the claim. So recovery can only REMOVE the factor and drop
the account to aal1. deleteFactor signs the target out everywhere, so they land
at login, use their password, and enrol again.

Three rules. The caller is an active manager read from the raw staff.role
column, never auth_staff_role() — 0039 makes that return 'manager' for drivers.
The caller must not owe an MFA challenge of their own, because a locked-out
manager still holds a valid aal1 session and without this a stolen password
alone could strip 2FA off any account. And the caller cannot target themselves.

The second rule is written as 'if you have a verified factor your aal must be
aal2' rather than a flat aal2 requirement, so the endpoint still works while
enrolment is optional and nobody has enrolled yet.
EOF
```

---

### Task 4: Dart service for the endpoint

**Files:**
- Create: `apps/amuwak_staff/lib/src/staff/reset_staff_mfa_service.dart`
- Create: `apps/amuwak_staff/test/staff/reset_staff_mfa_service_test.dart`
- Modify: `apps/amuwak_staff/lib/src/sync/repository_providers.dart`

**Interfaces:**
- Consumes: the `reset-staff-mfa` endpoint from Task 3.
- Produces:
  - `typedef ResetStaffMfaFn = Future<int> Function({required String staffId});`
  - `class ResetMfaFailure implements Exception { final String message; }`
  - `class ResetStaffMfaService { ResetStaffMfaService(SupabaseClient); Future<int> reset({required String staffId}); }`
  - `final resetStaffMfaServiceProvider = Provider<ResetStaffMfaService>(...)`

- [ ] **Step 1: Write the failing test**

Create `apps/amuwak_staff/test/staff/reset_staff_mfa_service_test.dart`:

```dart
import 'package:amuwak_staff/src/staff/reset_staff_mfa_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  late _MockClient client;
  late _MockFunctions functions;
  late ResetStaffMfaService service;

  setUp(() {
    client = _MockClient();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
    service = ResetStaffMfaService(client);
  });

  test('reports how many factors were cleared', () async {
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
      (_) async => FunctionResponse(data: {'factors_cleared': 1}, status: 200),
    );

    final cleared = await service.reset(staffId: 'staff-1');

    expect(cleared, 1);
    verify(() => functions.invoke('reset-staff-mfa',
        body: {'target_staff_id': 'staff-1'})).called(1);
  });

  test('treats a target with no factors as a success, not an error', () async {
    // Resetting someone who never enrolled is harmless and idempotent — the
    // manager should be told plainly, not shown a failure.
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenAnswer(
      (_) async => FunctionResponse(data: {'factors_cleared': 0}, status: 200),
    );

    expect(await service.reset(staffId: 'staff-1'), 0);
  });

  test('surfaces the server message so the manager sees the real reason',
      () async {
    when(() => functions.invoke(any(), body: any(named: 'body'))).thenThrow(
      FunctionException(
        status: 403,
        details: {'error': 'Only managers can do that'},
      ),
    );

    await expectLater(
      service.reset(staffId: 'staff-1'),
      throwsA(isA<ResetMfaFailure>().having(
          (e) => e.message, 'message', 'Only managers can do that')),
    );
  });

  test('falls back to a generic message when the server sends no detail',
      () async {
    when(() => functions.invoke(any(), body: any(named: 'body')))
        .thenThrow(FunctionException(status: 500));

    await expectLater(
      service.reset(staffId: 'staff-1'),
      throwsA(isA<ResetMfaFailure>().having((e) => e.message, 'message',
          contains('Could not reset'))),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd apps/amuwak_staff
flutter test test/staff/reset_staff_mfa_service_test.dart --timeout=none
```

Expected: FAIL — `Error when reading 'lib/src/staff/reset_staff_mfa_service.dart'`.

- [ ] **Step 3: Write the implementation**

Create `apps/amuwak_staff/lib/src/staff/reset_staff_mfa_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Callback shape the staff list depends on, so the screen can be tested with a
/// plain function instead of a live client. Mirrors [InviteStaffFn].
typedef ResetStaffMfaFn = Future<int> Function({required String staffId});

/// Raised when a reset can't be performed — caller isn't a manager, caller owes
/// their own MFA challenge, target not found. Carries the server's message.
class ResetMfaFailure implements Exception {
  ResetMfaFailure(this.message);
  final String message;
  @override
  String toString() => 'ResetMfaFailure: $message';
}

/// Clears a staff member's TOTP factors by calling the `reset-staff-mfa` Edge
/// Function, which runs with the service-role key and enforces the manager
/// check server-side. Nothing privileged happens in the client — the UI only
/// hides the button.
class ResetStaffMfaService {
  ResetStaffMfaService(this._client);

  final SupabaseClient _client;

  /// Returns the number of verified factors cleared. Zero is a success: the
  /// target simply had no authenticator set up.
  Future<int> reset({required String staffId}) async {
    try {
      final response = await _client.functions
          .invoke('reset-staff-mfa', body: {'target_staff_id': staffId});
      final data = response.data;
      if (data is Map && data['factors_cleared'] is int) {
        return data['factors_cleared'] as int;
      }
      return 0;
    } on FunctionException catch (e) {
      throw ResetMfaFailure(_messageFrom(e));
    }
  }

  /// Pulls the server's `{ "error": "..." }` body out of a FunctionException so
  /// the manager sees the real reason rather than a bare status code.
  static String _messageFrom(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.isNotEmpty) return details;
    return 'Could not reset their two-factor. Please try again.';
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/staff/reset_staff_mfa_service_test.dart --timeout=none
```

Expected: PASS, 4/4.

- [ ] **Step 5: Register the provider**

In `apps/amuwak_staff/lib/src/sync/repository_providers.dart`, next to
`inviteStaffServiceProvider` (around line 101), add the import and provider:

```dart
import '../staff/reset_staff_mfa_service.dart';

final resetStaffMfaServiceProvider = Provider<ResetStaffMfaService>(
  (ref) => ResetStaffMfaService(ref.watch(supabaseClientProvider)),
);
```

`supabaseClientProvider` is the same one `inviteStaffServiceProvider` uses two
lines above (`repository_providers.dart:101-103`).

- [ ] **Step 6: Commit**

```bash
git add apps/amuwak_staff/lib/src/staff/reset_staff_mfa_service.dart apps/amuwak_staff/test/staff/reset_staff_mfa_service_test.dart apps/amuwak_staff/lib/src/sync/repository_providers.dart
git commit --no-verify -F - -- apps/amuwak_staff/lib/src/staff/reset_staff_mfa_service.dart apps/amuwak_staff/test/staff/reset_staff_mfa_service_test.dart apps/amuwak_staff/lib/src/sync/repository_providers.dart <<'EOF'
feat(staff): client for the MFA reset endpoint

Mirrors InviteStaffService: the Edge Function holds the service-role key and
enforces the manager check, so nothing privileged lives here.

Zero cleared factors is a success rather than an error. Resetting someone who
never enrolled is harmless and idempotent, and the manager should be told
plainly instead of being shown a failure for a no-op.
EOF
```

---

### Task 5: Staff list screen and Account tab entry

**Files:**
- Create: `apps/amuwak_staff/lib/src/staff/staff_list_screen.dart`
- Create: `apps/amuwak_staff/test/staff/staff_list_screen_test.dart`
- Modify: `apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart`

**Interfaces:**
- Consumes: `ResetStaffMfaFn` (Task 4), `StaffRepository.watchAll()` (exists), `StaffData` from `src/data/app_database.dart`.
- Produces: `StaffListScreen({required Stream<List<StaffData>> staff, required ResetStaffMfaFn onReset, required String currentStaffId})`.

The screen takes its dependencies as parameters rather than reading providers,
matching `InviteStaffScreen(invite: service.invite)` — it keeps the widget test
free of Supabase.

- [ ] **Step 1: Write the failing test**

Create `apps/amuwak_staff/test/staff/staff_list_screen_test.dart`:

```dart
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/staff/reset_staff_mfa_service.dart';
import 'package:amuwak_staff/src/staff/staff_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

StaffData _staff(String id, String name, String role) => StaffData(
      id: id,
      username: name.toLowerCase(),
      displayName: name,
      role: role,
      active: true,
      mustChangePin: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  Widget harness({
    required ResetStaffMfaFn onReset,
    String currentStaffId = 'me',
  }) =>
      ProviderScope(
        child: MaterialApp(
          theme: buildAmuwakTheme(),
          home: StaffListScreen(
            staff: Stream.value([
              _staff('me', 'Manager Me', 'manager'),
              _staff('rider-1', 'Rider One', 'driver'),
            ]),
            onReset: onReset,
            currentStaffId: currentStaffId,
          ),
        ),
      );

  testWidgets('lists staff with their role', (tester) async {
    await tester.pumpWidget(harness(onReset: ({required staffId}) async => 0));
    await tester.pumpAndSettle();

    expect(find.text('Rider One'), findsOneWidget);
    expect(find.text('Manager Me'), findsOneWidget);
  });

  testWidgets('confirms before clearing someone else\'s two-factor',
      (tester) async {
    var called = 0;
    await tester.pumpWidget(harness(onReset: ({required staffId}) async {
      called++;
      return 1;
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();

    // Naming the person in the dialog matters: the list is tappable rows and
    // resetting the wrong rider silently locks them out of their shift.
    expect(find.textContaining('Rider One'), findsWidgets);
    expect(called, 0);

    await tester.tap(find.text('Reset two-factor'));
    await tester.pumpAndSettle();

    expect(called, 1);
  });

  testWidgets('says plainly when there was nothing to clear', (tester) async {
    await tester.pumpWidget(harness(onReset: ({required staffId}) async => 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset two-factor'));
    await tester.pumpAndSettle();

    expect(find.textContaining('had no two-factor'), findsOneWidget);
  });

  testWidgets('reports the server\'s reason when a reset is refused',
      (tester) async {
    await tester.pumpWidget(harness(onReset: ({required staffId}) async {
      throw ResetMfaFailure('Complete your own two-factor check first');
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset two-factor'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Complete your own two-factor check'),
        findsOneWidget);
  });

  testWidgets('does not offer a reset on your own row', (tester) async {
    // The server refuses self-reset; not offering it avoids walking the manager
    // into a guaranteed error.
    await tester.pumpWidget(harness(onReset: ({required staffId}) async => 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manager Me'));
    await tester.pumpAndSettle();

    expect(find.text('Reset two-factor'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/staff/staff_list_screen_test.dart --timeout=none
```

Expected: FAIL — `Error when reading 'lib/src/staff/staff_list_screen.dart'`.

- [ ] **Step 3: Write the screen**

Create `apps/amuwak_staff/lib/src/staff/staff_list_screen.dart`:

```dart
import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_header_content.dart'; // roleLabel
import '../data/app_database.dart';
import 'reset_staff_mfa_service.dart';

/// Managers-only list of staff, whose one action is clearing a lost
/// authenticator. RLS already allows this read: `staff_self_read` (migration
/// 0007) lets a manager select every staff row.
///
/// It deliberately does NOT show whether each person has two-factor on. Factor
/// status is admin-only data, so displaying it would mean a second privileged
/// endpoint for something cosmetic. The reset is idempotent instead and reports
/// what it actually did.
///
/// Dependencies arrive as parameters rather than through providers, matching
/// [InviteStaffScreen], so the widget test never touches Supabase.
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({
    super.key,
    required this.staff,
    required this.onReset,
    required this.currentStaffId,
  });

  final Stream<List<StaffData>> staff;
  final ResetStaffMfaFn onReset;

  /// Used to hide the reset action on the manager's own row. The server refuses
  /// a self-reset anyway; hiding it avoids walking them into a certain error.
  final String currentStaffId;

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  Future<void> _confirmAndReset(StaffData member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset two-factor?'),
        content: Text(
          '${member.displayName} will be signed out everywhere and will sign '
          'in with just their password, then set up a new authenticator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset two-factor'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final cleared = await widget.onReset(staffId: member.id);
      messenger.showSnackBar(SnackBar(
        content: Text(cleared == 0
            ? '${member.displayName} had no two-factor set up.'
            : 'Cleared two-factor for ${member.displayName}.'),
      ));
    } on ResetMfaFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not reset their two-factor. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: StreamBuilder<List<StaffData>>(
        stream: widget.staff,
        builder: (context, snapshot) {
          final members = snapshot.data;
          if (members == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: members.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final member = members[i];
              final isSelf = member.id == widget.currentStaffId;
              return AppCard(
                onTap: isSelf ? null : () => _confirmAndReset(member),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.displayName),
                          Text(
                            roleLabel(member.role) ?? member.role,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!isSelf) const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

`roleLabel` lives in `apps/amuwak_staff/lib/src/dashboard/dashboard_header_content.dart:26`,
not in `amuwak_core` — hence the import above.

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/staff/staff_list_screen_test.dart --timeout=none
```

Expected: PASS, 5/5.

- [ ] **Step 5: Add the Account tab entry**

In `apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart`:

Add the import beside the other `../staff/` imports:

```dart
import '../staff/staff_list_screen.dart';
```

Add an opener next to `_openInviteStaff` (around line 488):

```dart
  void _openStaffList() {
    final resetService = ref.read(resetStaffMfaServiceProvider);
    final staffRepo = ref.read(staffRepositoryProvider);
    final myId = ref.read(currentUserIdProvider) ?? '';
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StaffListScreen(
          staff: staffRepo.watchAll(),
          onReset: resetService.reset,
          currentStaffId: myId,
        ),
      ),
    );
  }
```

In the `_AccountTab(...)` call (around line 682) add `onOpenStaff: _openStaffList,`.

In `_AccountTab`, add the field beside `onInviteStaff`:

```dart
  /// Opens the managers-only staff list, whose action is clearing a lost
  /// authenticator.
  final VoidCallback onOpenStaff;
```

and to its constructor: `required this.onOpenStaff,`.

In `_AccountTab.build`, inside the existing `if (canInviteStaff) ...[` block so
it is gated the same way, directly above the Invite staff card:

```dart
          AppCard(
            onTap: onOpenStaff,
            child: Row(
              children: [
                Icon(Icons.groups_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: Text('Staff')),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg2),
```

`canInviteStaff` is `currentRoleProvider == 'manager'` — the JWT claim, which is
the true role, not the 0039-widened `auth_staff_role()`. That is the right gate.

- [ ] **Step 6: Add a dashboard test for the entry point**

In `apps/amuwak_staff/test/dashboard/staff_dashboard_screen_test.dart`, beside
the other Account-tab tests (around line 1427):

```dart
  testWidgets(
    'Account tab offers the Staff list to managers only',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpDashboardWithDb(tester, extraOverrides: [
        currentRoleProvider.overrideWith((ref) => 'manager'),
      ]);

      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();

      expect(find.text('Staff'), findsOneWidget);
    },
  );

  testWidgets(
    'Account tab hides the Staff list from drivers',
    (tester) async {
      // Gated on the JWT claim, not auth_staff_role() — 0039 widened that one
      // to call drivers managers.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpDashboardWithDb(tester, extraOverrides: [
        currentRoleProvider.overrideWith((ref) => 'driver'),
      ]);

      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();

      expect(find.text('Staff'), findsNothing);
    },
  );
```

- [ ] **Step 7: Run the affected suites and analyze**

Run each separately — never concurrently:

```bash
flutter test test/staff/staff_list_screen_test.dart --timeout=none
flutter test test/dashboard/staff_dashboard_screen_test.dart --timeout=none
flutter analyze
```

Expected: both suites pass, `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add apps/amuwak_staff/lib/src/staff/staff_list_screen.dart apps/amuwak_staff/test/staff/staff_list_screen_test.dart apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart apps/amuwak_staff/test/dashboard/staff_dashboard_screen_test.dart
git commit --no-verify -F - -- apps/amuwak_staff/lib/src/staff/staff_list_screen.dart apps/amuwak_staff/test/staff/staff_list_screen_test.dart apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart apps/amuwak_staff/test/dashboard/staff_dashboard_screen_test.dart <<'EOF'
feat(staff): managers-only staff list with MFA reset

The entry point for manager-mediated recovery. RLS already permits the read —
staff_self_read (0007) lets a manager select every staff row — so no migration
was needed.

It does not show per-person two-factor status: that is admin-only data, and a
second privileged endpoint for something cosmetic is not worth it. The reset is
idempotent and reports what it did, including that there was nothing to clear.

The dialog names the person because the list is tappable rows and resetting the
wrong rider silently locks them out of their shift. The reset is hidden on the
manager's own row since the server refuses it anyway.
EOF
```

---

## Final verification

- [ ] `supabase test db` — 0054 (8) and 0055 (4) pass. `0015_powersync` fails 15/15 for pre-existing reasons; judge per-file, not by exit code.
- [ ] `flutter analyze` in `apps/amuwak_staff` and `packages/amuwak_core` — `No issues found!`
- [ ] `flutter test --timeout=none` in `apps/amuwak_staff` — full suite green (877 before this plan).
- [ ] **`supabase db push`** — apply 0054 and 0055 to production.
- [ ] `supabase functions deploy reset-staff-mfa`, then work Task 3 Step 3's seven manual checks against the real project.
- [ ] Confirm a second active manager exists in production before enforcing `aal2`.

### Deployment order (it matters)

**Push migrations → deploy the function → merge.** The three pieces ship by
different routes and only the app is automatic: merging to `main` fires
`deploy-pwa.yml` on push, while `db push` and `functions deploy` are manual.

If the function reaches production before 0055, every reset succeeds, returns
200, and writes nothing — the audit table it needs does not exist yet, and the
insert failure is logged server-side where no operator is looking. That is
exactly the invisibility 0055 was added to prevent. If the app merges first,
managers simply get an error when they tap through, which is recoverable and
obvious.

(An earlier draft added a third migration, 0056, here. It was written against a
premise that turned out to be false and closed no live hole — see the correction
at the top of this plan — so it was dropped. Only 0054 and 0055 ship.)
