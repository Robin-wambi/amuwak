# MFA Recovery Codes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a staff member who has lost their authenticator get back into the app on their own, using a one-time recovery code issued when they enrolled.

**Architecture:** Postgres owns the secrets — a `mfa_recovery_codes` table with RLS on and zero policies, reachable only through two `SECURITY DEFINER` functions. An Edge Function owns factor deletion, because no migration in this repo writes to `auth.*` and a locked-out user cannot unenrol themselves (GoTrue requires `aal2` to unenrol a verified factor). Redeeming a code deletes the user's TOTP factor, dropping them to `aal1`, so the existing `AuthGate` lets them through with no new routing.

**Tech Stack:** Postgres 17 + pgcrypto (bcrypt), pgTAP, Supabase Edge Functions (Deno), Flutter/Dart, Riverpod, mocktail.

**Design doc:** `docs/superpowers/specs/2026-08-06-mfa-recovery-codes-design.md`

## Global Constraints

- Branch: `feat/mfa-recovery-codes`, off `feat/mfa-foundation` (PR #105, now based on `main`).
- Migration prefix **0054**. 0053 is the latest; `migrations-lint` CI rejects duplicate prefixes.
- pgcrypto lives in the `extensions` schema. Every function sets `search_path = public`, so crypto calls **must** be schema-qualified: `extensions.gen_random_bytes`, `extensions.crypt`, `extensions.gen_salt`.
- Local DB URL: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- **Do not run `supabase db reset` or `supabase test db`** — both wipe the running dev database. Apply and test with `psql` (pgTAP files are wrapped in `BEGIN; … ROLLBACK;` so they leave no trace).
- The Edge Function **cannot be verified locally** — `supabase_edge_runtime` is stopped. Its correctness is confirmed only on deploy.
- Code format: 10 random bytes → 20 uppercase hex chars → four groups of five, `XXXXX-XXXXX-XXXXX-XXXXX`. Hashes store the **undashed, uppercase** form; redemption normalises to it.
- Run Flutter tests one file at a time on this host; a `+0 -1` stall on the `loading` line is the slow host, not a failure.
- Commit with `git commit -F <file>` and scoped paths.

---

### Task 1: Migration 0054 — table, RLS, and both functions

**Files:**
- Create: `supabase/migrations/0054_mfa_recovery_codes.sql`
- Test: `supabase/tests/0054_mfa_recovery_codes_test.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: `generate_mfa_recovery_codes() RETURNS text[]` and `redeem_mfa_recovery_code(p_code text) RETURNS boolean`, both `GRANT EXECUTE TO authenticated`.

- [ ] **Step 1: Write the failing pgTAP test**

Create `supabase/tests/0054_mfa_recovery_codes_test.sql`:

```sql
-- 0054_mfa_recovery_codes_test.sql
-- Recovery codes: a locked-out staff member's self-service way back in.
-- The load-bearing test is #3 — an aal1 caller must not be able to mint codes,
-- or two-factor is defeated by password alone.

BEGIN;
SET search_path TO extensions, public;

SELECT plan(11);

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
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'),
  10,
  'regenerating replaces the previous set');

-- 8-11. Redemption. Mint a known set and redeem one of them.
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
SELECT is(
  (SELECT count(*)::int FROM mfa_recovery_codes
    WHERE user_id = '00000000-0000-0000-0000-0000000000e1'),
  1,
  'redemption clears the remaining codes, keeping the burned one');

-- Another user's code is not accepted.
SET LOCAL "request.jwt.claims" =
  '{"sub":"00000000-0000-0000-0000-0000000000e2","aal":"aal2"}';
PERFORM generate_mfa_recovery_codes();
SELECT ok(
  NOT redeem_mfa_recovery_code((SELECT code FROM issued OFFSET 1 LIMIT 1)),
  'another user''s code is refused');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run it to verify it fails**

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -f supabase/tests/0054_mfa_recovery_codes_test.sql
```

Expected: FAIL — `relation "mfa_recovery_codes" does not exist`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0054_mfa_recovery_codes.sql`:

```sql
-- 0054_mfa_recovery_codes.sql
-- Self-service recovery for a staff member who has lost their authenticator.
--
-- Supabase has no native recovery codes, and a recovery code CANNOT mint an
-- aal2 session — GoTrue issues aal2 only from a verified factor challenge. So
-- redeeming a code means deleting the user's TOTP factor, dropping them back to
-- aal1 so the challenge stops appearing. The factor deletion itself lives in the
-- `redeem-recovery-code` Edge Function: no migration here writes to auth.*, and
-- a locked-out user cannot unenrol themselves (GoTrue requires aal2 to unenrol a
-- verified factor). This migration owns only the secrets.

CREATE TABLE mfa_recovery_codes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash  text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  used_at    timestamptz
);

CREATE INDEX mfa_recovery_codes_unused_idx
  ON mfa_recovery_codes (user_id) WHERE used_at IS NULL;

-- RLS on with DELIBERATELY ZERO POLICIES denies everyone, including the row's
-- owner. Combined with the REVOKE below, the only way in is the two SECURITY
-- DEFINER functions. Nobody ever reads their own hashes.
ALTER TABLE mfa_recovery_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON mfa_recovery_codes FROM anon, authenticated;

-- Mint ten codes, replacing any previous set.
--
-- The aal2 check is the security control the whole feature rests on. Without
-- it: sign in with password (aal1) -> generate -> receive ten plaintext codes ->
-- redeem one -> factor deleted -> two-factor defeated by the password alone.
-- Written as IS DISTINCT FROM so a missing or null claim fails CLOSED.
CREATE FUNCTION generate_mfa_recovery_codes()
RETURNS text[]
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user  uuid := auth.uid();
  v_aal   text := auth.jwt() ->> 'aal';
  v_codes text[] := '{}';
  v_raw   text;
  i       int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'generate_mfa_recovery_codes requires a signed-in caller';
  END IF;
  IF v_aal IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'generate_mfa_recovery_codes requires an aal2 session';
  END IF;

  DELETE FROM mfa_recovery_codes WHERE user_id = v_user;

  FOR i IN 1..10 LOOP
    -- 10 bytes = 80 bits, rendered as 20 uppercase hex characters.
    v_raw := upper(encode(extensions.gen_random_bytes(10), 'hex'));
    INSERT INTO mfa_recovery_codes (user_id, code_hash)
      VALUES (v_user, extensions.crypt(v_raw, extensions.gen_salt('bf')));
    -- Stored undashed; the dashes are for the human transcribing it.
    v_codes := array_append(v_codes,
      substr(v_raw,  1, 5) || '-' || substr(v_raw,  6, 5) || '-' ||
      substr(v_raw, 11, 5) || '-' || substr(v_raw, 16, 5));
  END LOOP;

  RETURN v_codes;
END;
$$;

-- Burn one code. Returns false for anything unrecognised — the caller decides
-- what to tell the user, and this must not leak whether a code merely belongs
-- to somebody else.
--
-- bcrypt cannot be looked up by value, so this walks the caller's unused rows.
-- At most ten verifications on a rare path.
CREATE FUNCTION redeem_mfa_recovery_code(p_code text)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_norm text;
  v_id   uuid;
  r      record;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'redeem_mfa_recovery_code requires a signed-in caller';
  END IF;

  -- Accept whatever the user typed: dashes, spaces, lowercase.
  v_norm := upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Za-z]', '', 'g'));
  IF v_norm = '' THEN RETURN false; END IF;

  FOR r IN SELECT id, code_hash FROM mfa_recovery_codes
            WHERE user_id = v_user AND used_at IS NULL
  LOOP
    IF extensions.crypt(v_norm, r.code_hash) = r.code_hash THEN
      v_id := r.id;
      EXIT;
    END IF;
  END LOOP;

  IF v_id IS NULL THEN RETURN false; END IF;

  -- Atomic burn: concurrent redemptions of one code cannot both win.
  UPDATE mfa_recovery_codes SET used_at = now()
   WHERE id = v_id AND used_at IS NULL;
  IF NOT FOUND THEN RETURN false; END IF;

  -- Two-factor is about to be switched off; the rest are dangling credentials.
  -- The burned row stays as an audit trail.
  DELETE FROM mfa_recovery_codes WHERE user_id = v_user AND id <> v_id;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION generate_mfa_recovery_codes()      FROM public;
GRANT  EXECUTE ON FUNCTION generate_mfa_recovery_codes()      TO authenticated;
REVOKE EXECUTE ON FUNCTION redeem_mfa_recovery_code(text)     FROM public;
GRANT  EXECUTE ON FUNCTION redeem_mfa_recovery_code(text)     TO authenticated;
```

- [ ] **Step 4: Apply it and run the test**

```bash
DB="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
psql "$DB" -f supabase/migrations/0054_mfa_recovery_codes.sql
psql "$DB" -f supabase/tests/0054_mfa_recovery_codes_test.sql
```

Expected: `ok 1` … `ok 11`, no `not ok`.

If a test fails, fix the migration, then re-apply from a clean slate:
`psql "$DB" -c "DROP TABLE IF EXISTS mfa_recovery_codes CASCADE; DROP FUNCTION IF EXISTS generate_mfa_recovery_codes(); DROP FUNCTION IF EXISTS redeem_mfa_recovery_code(text);"`

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0054_mfa_recovery_codes.sql \
        supabase/tests/0054_mfa_recovery_codes_test.sql
git commit -F <message-file>
```

Message: `feat(mfa): recovery codes table, RLS, and mint/redeem functions`

---

### Task 2: Edge Function `redeem-recovery-code`

**Files:**
- Create: `supabase/functions/redeem-recovery-code/index.ts`

**Interfaces:**
- Consumes: `redeem_mfa_recovery_code(p_code text) RETURNS boolean` from Task 1.
- Produces: `POST /functions/v1/redeem-recovery-code` with body `{ "code": "XXXXX-..." }`, returning `200 {"ok":true}` or `4xx/5xx {"error":"..."}`.

**Cannot be tested locally** — the edge runtime is stopped. Verify by reading, then on deploy.

- [ ] **Step 1: Write the function**

Create `supabase/functions/redeem-recovery-code/index.ts`:

```ts
// redeem-recovery-code
// -----------------------------------------------------------------------------
// Lets a staff member who has lost their authenticator back in, using a one-time
// recovery code.
//
// A recovery code cannot mint an aal2 session — GoTrue issues aal2 only from a
// verified factor challenge. So redemption DELETES the user's TOTP factor, which
// drops nextLevel to aal1 and stops the challenge appearing. That requires the
// admin API, hence the service-role key, hence this function.
//
// Order is burn-then-delete: the RPC burns the code atomically first. If the
// admin call then fails the user has spent a code and is still locked out, with
// nine left — logged loudly below, because that is the case that strands them.
// The alternative (delete first, burn after) leaves a window where one code is
// accepted twice.
//
// The caller is identified from their own JWT — an aal1 session is expected here
// and is fine, but there is NO anonymous path: an attacker needs the password
// AND a code.
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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return json({ error: 'Not signed in.' }, 401);

  let code: unknown;
  try {
    code = (await req.json())?.code;
  } catch {
    return json({ error: 'Malformed request.' }, 400);
  }
  if (typeof code !== 'string' || code.trim() === '') {
    return json({ error: 'Enter a recovery code.' }, 400);
  }

  // As the CALLER, not the service role: this makes auth.uid() resolve inside
  // the RPC, so no user id is accepted from the request body and there is
  // nothing to spoof.
  const asCaller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userErr } = await asCaller.auth.getUser();
  if (userErr || !userData?.user) return json({ error: 'Not signed in.' }, 401);
  const userId = userData.user.id;

  const { data: accepted, error: rpcErr } =
    await asCaller.rpc('redeem_mfa_recovery_code', { p_code: code });

  if (rpcErr) {
    console.error('redeem rpc failed', { userId, message: rpcErr.message });
    return json({ error: 'Could not check that code. Please try again.' }, 500);
  }
  if (accepted !== true) {
    return json({ error: 'That recovery code is not valid.' }, 400);
  }

  // The code is spent. Now drop the factors it bought removal of.
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: factors, error: listErr } =
    await admin.auth.admin.mfa.listFactors({ userId });

  if (listErr) {
    console.error('CODE BURNED BUT LIST FAILED — user may be stuck', {
      userId, message: listErr.message,
    });
    return json({ error: 'Could not complete recovery. Try another code.' }, 500);
  }

  for (const factor of factors?.factors ?? []) {
    if (factor.status !== 'verified') continue;
    const { error: delErr } =
      await admin.auth.admin.mfa.deleteFactor({ userId, id: factor.id });
    if (delErr) {
      console.error('CODE BURNED BUT DELETE FAILED — user is stuck', {
        userId, factorId: factor.id, message: delErr.message,
      });
      return json({ error: 'Could not complete recovery. Try another code.' }, 500);
    }
  }

  return json({ ok: true }, 200);
});
```

- [ ] **Step 2: Type-check it**

```bash
deno check supabase/functions/redeem-recovery-code/index.ts
```

Expected: no errors. If `deno` is unavailable, skip — CI does not check these either; note it in the commit body.

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/redeem-recovery-code/index.ts
git commit -F <message-file>
```

Message: `feat(mfa): redeem-recovery-code Edge Function`

---

### Task 3: Core `RecoveryCodesService`

**Files:**
- Create: `packages/amuwak_core/lib/src/auth/recovery_codes_service.dart`
- Modify: `packages/amuwak_core/lib/amuwak_core.dart` (add the export)
- Modify: `packages/amuwak_core/lib/src/auth/session.dart` (add the provider)
- Test: `packages/amuwak_core/test/auth/recovery_codes_service_test.dart`

**Interfaces:**
- Consumes: Task 1's RPC, Task 2's function name. `AuthFailure(String message, {bool retryable})` already exists in `auth_service.dart`.
- Produces:
  - `class RecoveryCodesService { RecoveryCodesService({SupabaseClient? client}); Future<List<String>> generate(); Future<void> redeem(String code); }`
  - `final recoveryCodesServiceProvider = Provider<RecoveryCodesService>(...)`

- [ ] **Step 1: Write the failing test**

Create `packages/amuwak_core/test/auth/recovery_codes_service_test.dart`:

```dart
import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  late _MockClient client;
  late _MockFunctions functions;
  late RecoveryCodesService service;

  setUp(() {
    client = _MockClient();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
    service = RecoveryCodesService(client: client);
  });

  group('generate', () {
    test('returns the codes the server minted', () async {
      when(() => client.rpc<dynamic>('generate_mfa_recovery_codes'))
          .thenAnswer((_) async => ['AAAAA-BBBBB-CCCCC-DDDDD', 'EEEEE-FFFFF-00000-11111']);

      final codes = await service.generate();

      expect(codes, hasLength(2));
      expect(codes.first, 'AAAAA-BBBBB-CCCCC-DDDDD');
    });

    test('an aal1 caller is rejected, not silently given codes', () async {
      // The database raises here. Surfacing it as AuthFailure keeps the UI on
      // one error type.
      when(() => client.rpc<dynamic>('generate_mfa_recovery_codes'))
          .thenThrow(PostgrestException(
              message: 'generate_mfa_recovery_codes requires an aal2 session'));

      await expectLater(service.generate(), throwsA(isA<AuthFailure>()));
    });
  });

  group('redeem', () {
    test('posts the code to the edge function', () async {
      when(() => functions.invoke('redeem-recovery-code',
              body: any(named: 'body')))
          .thenAnswer((_) async => FunctionResponse(status: 200, data: {'ok': true}));

      await service.redeem('AAAAA-BBBBB-CCCCC-DDDDD');

      verify(() => functions.invoke('redeem-recovery-code',
          body: {'code': 'AAAAA-BBBBB-CCCCC-DDDDD'})).called(1);
    });

    test('a rejected code surfaces the server message', () async {
      when(() => functions.invoke('redeem-recovery-code',
              body: any(named: 'body')))
          .thenThrow(FunctionException(
              status: 400, details: {'error': 'That recovery code is not valid.'}));

      await expectLater(
        service.redeem('NOPE'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.message, 'message', contains('not valid'))
            .having((f) => f.retryable, 'retryable', isFalse)),
      );
    });

    test('a server-side failure is retryable, a bad code is not', () async {
      // 5xx means we never got a verdict — "try again" is honest advice here
      // and misleading for a 400.
      when(() => functions.invoke('redeem-recovery-code',
              body: any(named: 'body')))
          .thenThrow(FunctionException(
              status: 500, details: {'error': 'Could not check that code.'}));

      await expectLater(
        service.redeem('AAAAA-BBBBB-CCCCC-DDDDD'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.retryable, 'retryable', isTrue)),
      );
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd packages/amuwak_core && flutter test test/auth/recovery_codes_service_test.dart --timeout=none
```

Expected: FAIL — `Undefined class 'RecoveryCodesService'`.

> **Known risk — read before fighting the mock.** `SupabaseClient.rpc<T>()` returns
> a `PostgrestFilterBuilder<T>`, not a `Future`. It is awaitable because the
> builder implements `Future`, but mocktail has to return that builder type, and
> `thenAnswer((_) async => [...])` may not typecheck against it.
>
> If that happens, do **not** contort the test. Give the service a seam instead:
>
> ```dart
> typedef RpcFn = Future<dynamic> Function(String fn);
>
> class RecoveryCodesService {
>   RecoveryCodesService({SupabaseClient? client, RpcFn? rpc})
>       : _client = client ?? Supabase.instance.client,
>         _rpc = rpc;
>
>   final RpcFn? _rpc;
>
>   Future<dynamic> _callRpc(String fn) =>
>       _rpc != null ? _rpc!(fn) : _client.rpc<dynamic>(fn);
> }
> ```
>
> then have `generate()` call `_callRpc('generate_mfa_recovery_codes')` and pass
> a plain function from the test. Same behaviour, testable, no mock gymnastics.
> Record which route you took in the commit body.

- [ ] **Step 3: Write the service**

Create `packages/amuwak_core/lib/src/auth/recovery_codes_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Recovery codes: the way back in for a staff member who has lost their
/// authenticator.
///
/// The two paths are deliberately asymmetric.
///
///   * [generate] calls the RPC directly. The caller is already at aal2 and
///     needs no elevated privilege.
///   * [redeem] goes through the `redeem-recovery-code` Edge Function and NEVER
///     the RPC directly. The RPC alone burns the code without deleting the
///     factor, which would leave the user locked out and a code down.
///
/// After a successful [redeem] the caller must refresh the session: the
/// assurance level is computed from factors cached on the session user, so
/// without a refresh the gate would not notice the factor is gone.
class RecoveryCodesService {
  RecoveryCodesService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Mint a fresh set, replacing any previous one. The plaintext exists only in
  /// this return value — it is never stored and never retrievable again.
  Future<List<String>> generate() async {
    try {
      final result = await _client.rpc<dynamic>('generate_mfa_recovery_codes');
      return (result as List).cast<String>();
    } on PostgrestException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Spend a code. On success the user's TOTP factor is gone and two-factor is
  /// off until they enrol again.
  Future<void> redeem(String code) async {
    try {
      await _client.functions
          .invoke('redeem-recovery-code', body: {'code': code});
    } on FunctionException catch (e) {
      // A 5xx never reached a verdict, so "try again" is honest. A 400 means
      // the code was read and rejected — retrying it changes nothing.
      throw AuthFailure(_messageFrom(e), retryable: e.status >= 500);
    }
  }

  static String _messageFrom(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Could not use that recovery code. Please try again.';
  }
}
```

- [ ] **Step 4: Export it and add the provider**

In `packages/amuwak_core/lib/amuwak_core.dart`, beside the `mfa_service.dart` export:

```dart
export 'src/auth/recovery_codes_service.dart';
```

In `packages/amuwak_core/lib/src/auth/session.dart`, beside `mfaServiceProvider`:

```dart
final recoveryCodesServiceProvider =
    Provider<RecoveryCodesService>((ref) => RecoveryCodesService());
```

and add `import 'recovery_codes_service.dart';` at the top.

- [ ] **Step 5: Run the test to verify it passes**

```bash
cd packages/amuwak_core && flutter test test/auth/recovery_codes_service_test.dart --timeout=none
cd packages/amuwak_core && flutter analyze
```

Expected: all tests PASS, analyze clean.

- [ ] **Step 6: Commit**

```bash
git add packages/amuwak_core/lib/src/auth/recovery_codes_service.dart \
        packages/amuwak_core/lib/amuwak_core.dart \
        packages/amuwak_core/lib/src/auth/session.dart \
        packages/amuwak_core/test/auth/recovery_codes_service_test.dart
git commit -F <message-file>
```

Message: `feat(core): RecoveryCodesService for minting and spending codes`

---

### Task 4: The recovery-codes screen

**Files:**
- Create: `apps/amuwak_staff/lib/src/auth/recovery_codes_screen.dart`
- Test: `apps/amuwak_staff/test/auth/recovery_codes_screen_test.dart`

**Interfaces:**
- Consumes: `recoveryCodesServiceProvider`, `RecoveryCodesService.generate()`.
- Produces: `RecoveryCodesScreen({required VoidCallback onAcknowledged})`.

- [ ] **Step 1: Write the failing test**

Create `apps/amuwak_staff/test/auth/recovery_codes_screen_test.dart`:

```dart
import 'dart:async';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/auth/recovery_codes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecovery extends Mock implements RecoveryCodesService {}

const _codes = [
  'AAAAA-BBBBB-CCCCC-DDDDD',
  'EEEEE-FFFFF-00000-11111',
  '22222-33333-44444-55555',
];

void main() {
  late _MockRecovery recovery;
  int acknowledged = 0;

  setUp(() {
    recovery = _MockRecovery();
    acknowledged = 0;
    when(() => recovery.generate()).thenAnswer((_) async => _codes);
  });

  Widget harness() => ProviderScope(
        overrides: [recoveryCodesServiceProvider.overrideWithValue(recovery)],
        child: MaterialApp(
          theme: buildAmuwakTheme(),
          home: RecoveryCodesScreen(onAcknowledged: () => acknowledged++),
        ),
      );

  testWidgets('shows every code it was given', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    for (final code in _codes) {
      expect(find.text(code), findsOneWidget);
    }
  });

  testWidgets('cannot be dismissed without confirming they are saved',
      (tester) async {
    // These are shown exactly once. Letting the screen close on a stray back
    // gesture hands someone a two-factor account with no way back into it.
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(acknowledged, 0);
    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();

    expect(acknowledged, 1);
  });

  testWidgets('shows a spinner rather than an empty list while minting',
      (tester) async {
    final pending = Completer<List<String>>();
    when(() => recovery.generate()).thenAnswer((_) => pending.future);

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("I've saved these"), findsNothing);

    pending.complete(_codes);
    await tester.pumpAndSettle();
    expect(find.text("I've saved these"), findsOneWidget);
  });

  testWidgets('offers a retry when minting fails', (tester) async {
    when(() => recovery.generate())
        .thenThrow(AuthFailure('connection closed', retryable: true));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not create'), findsOneWidget);
    expect(acknowledged, 0);

    when(() => recovery.generate()).thenAnswer((_) async => _codes);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text(_codes.first), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd apps/amuwak_staff && flutter test test/auth/recovery_codes_screen_test.dart --timeout=none
```

Expected: FAIL — `Undefined class 'RecoveryCodesScreen'`.

- [ ] **Step 3: Write the screen**

Create `apps/amuwak_staff/lib/src/auth/recovery_codes_screen.dart`:

```dart
import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the recovery codes, once.
///
/// This is the only moment the plaintext exists — the server keeps bcrypt
/// hashes and cannot show them again. The screen therefore has no back
/// affordance and no way out except acknowledging: a staff member who taps past
/// it owns a two-factor account with no way back into it.
class RecoveryCodesScreen extends ConsumerStatefulWidget {
  const RecoveryCodesScreen({super.key, required this.onAcknowledged});

  /// Called once the user confirms they have stored the codes. The caller
  /// closes this screen.
  final VoidCallback onAcknowledged;

  @override
  ConsumerState<RecoveryCodesScreen> createState() =>
      _RecoveryCodesScreenState();
}

class _RecoveryCodesScreenState extends ConsumerState<RecoveryCodesScreen> {
  List<String>? _codes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mint();
  }

  Future<void> _mint() async {
    if (_error != null) setState(() => _error = null);
    try {
      final codes = await ref.read(recoveryCodesServiceProvider).generate();
      if (mounted) setState(() => _codes = codes);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not create recovery codes. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // No accidental exit: the codes are unrecoverable once this closes.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recovery codes'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _body(theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _mint, child: const Text('Retry')),
        ],
      );
    }
    final codes = _codes;
    if (codes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Save these somewhere safe. If you lose your phone, one of these '
          'codes is how you get back in. Each works once, and they will not be '
          'shown again.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final code in codes) ...[
          SelectableText(code,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: codes.join('\n')));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recovery codes copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy'),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: widget.onAcknowledged,
          child: const Text("I've saved these"),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd apps/amuwak_staff && flutter test test/auth/recovery_codes_screen_test.dart --timeout=none
```

Expected: all four PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/amuwak_staff/lib/src/auth/recovery_codes_screen.dart \
        apps/amuwak_staff/test/auth/recovery_codes_screen_test.dart
git commit -F <message-file>
```

Message: `feat(staff): show recovery codes once, with no way past them`

---

### Task 5: Issue codes at the end of enrolment

**Files:**
- Modify: `apps/amuwak_staff/lib/src/auth/mfa_enrolment_screen.dart`
- Test: `apps/amuwak_staff/test/auth/mfa_enrolment_screen_test.dart`

**Interfaces:**
- Consumes: `RecoveryCodesScreen` (Task 4), the existing `MfaChangedFn onCompleted({required bool enabled})`.
- Produces: no new API. `onCompleted(enabled: true)` now fires only after the codes are acknowledged.

- [ ] **Step 1: Write the failing test**

In `apps/amuwak_staff/test/auth/mfa_enrolment_screen_test.dart`, first add these imports:

```dart
import 'package:amuwak_staff/src/auth/recovery_codes_screen.dart';
```

this mock class beside the existing `_MockMfa`:

```dart
class _MockRecovery extends Mock implements RecoveryCodesService {}
```

this variable beside `late _MockMfa mfa;`:

```dart
  late _MockRecovery recovery;
```

these two lines at the end of `setUp`:

```dart
    recovery = _MockRecovery();
    when(() => recovery.generate())
        .thenAnswer((_) async => ['AAAAA-BBBBB-CCCCC-DDDDD']);
```

and this override in `harness()`'s `overrides` list:

```dart
          recoveryCodesServiceProvider.overrideWithValue(recovery),
```

Then append this test inside `main`:

```dart
  testWidgets('hands over the recovery codes before reporting success',
      (tester) async {
    // Enrolling without codes creates exactly the lockout this feature exists
    // to prevent, so completion waits until the user has them.
    stubEnroll();
    when(() => mfa.submitCode(
        factorId: any(named: 'factorId'),
        code: any(named: 'code'))).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    expect(find.byType(RecoveryCodesScreen), findsOneWidget);
    expect(completed, 0, reason: 'not done until the codes are acknowledged');

    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(lastEnabled, isTrue);
  });
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd apps/amuwak_staff && flutter test test/auth/mfa_enrolment_screen_test.dart --timeout=none
```

Expected: FAIL — `RecoveryCodesScreen` not found; `completed` is already 1.

- [ ] **Step 3: Push the codes screen before completing**

In `mfa_enrolment_screen.dart`, add `import 'recovery_codes_screen.dart';`, then replace the success line in `_activate`:

```dart
      await ref
          .read(mfaServiceProvider)
          .submitCode(factorId: enrolment.factorId, code: _code.text.trim());
      if (mounted) await _handOverRecoveryCodes();
```

and add the method:

```dart
  /// The factor is live but the user has no way back in if they lose it. Hand
  /// over the recovery codes before declaring success — this is the only moment
  /// the plaintext exists.
  Future<void> _handOverRecoveryCodes() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => RecoveryCodesScreen(
          onAcknowledged: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (mounted) widget.onCompleted(enabled: true);
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd apps/amuwak_staff && flutter test test/auth/mfa_enrolment_screen_test.dart --timeout=none
```

Expected: all PASS, including the pre-existing enrolment tests.

- [ ] **Step 5: Commit**

```bash
git add apps/amuwak_staff/lib/src/auth/mfa_enrolment_screen.dart \
        apps/amuwak_staff/test/auth/mfa_enrolment_screen_test.dart
git commit -F <message-file>
```

Message: `feat(staff): issue recovery codes when enrolment completes`

---

### Task 6: Redeem a code from the challenge screen

**Files:**
- Modify: `apps/amuwak_staff/lib/src/auth/mfa_challenge_screen.dart`
- Test: `apps/amuwak_staff/test/auth/mfa_challenge_screen_test.dart`

**Interfaces:**
- Consumes: `recoveryCodesServiceProvider.redeem(String)`, `authServiceProvider.refreshSession()` (already exists on `AuthService`).
- Produces: no new API.

- [ ] **Step 1: Write the failing test**

Append to `apps/amuwak_staff/test/auth/mfa_challenge_screen_test.dart`. Add a `_MockRecovery extends Mock implements RecoveryCodesService` class and `recoveryCodesServiceProvider.overrideWithValue(recovery)` to `harness()`, with `recovery` created in `setUp`:

```dart
  testWidgets('a recovery code gets a locked-out user back in', (tester) async {
    // The whole point: no manager, no Supabase dashboard.
    when(() => recovery.redeem(any())).thenAnswer((_) async {});
    when(() => auth.refreshSession()).thenAnswer((_) async {});

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'AAAAA-BBBBB-CCCCC-DDDDD');
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();

    verify(() => recovery.redeem('AAAAA-BBBBB-CCCCC-DDDDD')).called(1);
    // Without the refresh the gate never notices: the assurance level is read
    // from factors cached on the session user.
    verify(() => auth.refreshSession()).called(1);
  });

  testWidgets('a rejected recovery code keeps the field usable',
      (tester) async {
    when(() => recovery.redeem(any()))
        .thenThrow(AuthFailure('That recovery code is not valid.'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'NOPE1-NOPE2-NOPE3-NOPE4');
    await tester.tap(find.text('Use code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not valid'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('can go back to the authenticator code', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();
    expect(find.text('Verify'), findsNothing);

    await tester.tap(find.text('Use my authenticator instead'));
    await tester.pumpAndSettle();
    expect(find.text('Verify'), findsOneWidget);
  });
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd apps/amuwak_staff && flutter test test/auth/mfa_challenge_screen_test.dart --timeout=none
```

Expected: FAIL — no `Use a recovery code` widget.

- [ ] **Step 3: Add the recovery mode**

In `mfa_challenge_screen.dart`: add `bool _recoveryMode = false;` to the state, and in `_stageContent`'s `_FactorLoad.ready` branch return the recovery form when `_recoveryMode` is true:

```dart
      case _FactorLoad.ready:
        if (_recoveryMode) {
          return [
            Text(
              'Enter one of the recovery codes you saved when you set up '
              'two-factor. Using one switches two-factor off until you set it '
              'up again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _code,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Recovery code'),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Enter a recovery code'
                    : null,
              ),
            ),
          ];
        }
        return [ /* the existing list, unchanged: the "Enter the current
                    6-digit code..." Text, the SizedBox, and the Form wrapping
                    the digits-only TextFormField */ ];
```

Everything else in `_stageContent` — the `failed`, `none`, and `loading` branches — stays exactly as it is. `_recoveryMode` only ever alters the `ready` branch, because there is nothing to recover from until a factor is known to exist.

Replace the `ready` action list in `_actions` with a mode-aware version:

```dart
      case _FactorLoad.ready:
        return [
          FilledButton(
            onPressed: _busy ? null : (_recoveryMode ? _useRecoveryCode : _verify),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_recoveryMode ? 'Use code' : 'Verify'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _recoveryMode = !_recoveryMode;
                      _code.clear();
                      _error = null;
                    }),
            child: Text(_recoveryMode
                ? 'Use my authenticator instead'
                : 'Use a recovery code'),
          ),
        ];
```

Add the handler:

```dart
  /// Spend a recovery code. On success the factor is gone, so the session must
  /// be refreshed before the gate will notice — the assurance level is computed
  /// from factors cached on the session user, not re-fetched.
  Future<void> _useRecoveryCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(recoveryCodesServiceProvider).redeem(_code.text.trim());
      await ref.read(authServiceProvider).refreshSession();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is AuthFailure
            ? e.message
            : 'Could not use that recovery code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd apps/amuwak_staff && flutter test test/auth/mfa_challenge_screen_test.dart --timeout=none
```

Expected: all PASS, including the twelve pre-existing challenge tests.

- [ ] **Step 5: Commit**

```bash
git add apps/amuwak_staff/lib/src/auth/mfa_challenge_screen.dart \
        apps/amuwak_staff/test/auth/mfa_challenge_screen_test.dart
git commit -F <message-file>
```

Message: `feat(staff): redeem a recovery code from the two-factor challenge`

---

### Task 7: Regenerate codes from Account

**Files:**
- Modify: `apps/amuwak_staff/lib/src/auth/mfa_enrolment_screen.dart`
- Test: `apps/amuwak_staff/test/auth/mfa_enrolment_screen_test.dart`

**Interfaces:**
- Consumes: `RecoveryCodesScreen` (Task 4), and the `_MockRecovery` mock,
  `recovery` variable, `setUp` stub and `harness()` override that **Task 5 added
  to this same test file**. Do Task 5 first; this task assumes they are present.
- Produces: no new API. The `_Stage.enrolled` view gains a second action.

- [ ] **Step 1: Write the failing test**

Append to `apps/amuwak_staff/test/auth/mfa_enrolment_screen_test.dart`:

```dart
  testWidgets('an enrolled user can replace their recovery codes',
      (tester) async {
    // Someone who used a code, or lost the paper, needs a fresh set without
    // having to turn two-factor off and on again.
    when(() => mfa.verifiedFactors())
        .thenAnswer((_) async => [_verified('factor-1')]);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace recovery codes'));
    await tester.pumpAndSettle();

    expect(find.byType(RecoveryCodesScreen), findsOneWidget);
    verify(() => recovery.generate()).called(1);

    await tester.tap(find.text("I've saved these"));
    await tester.pumpAndSettle();

    // Replacing codes is not the same as turning two-factor off.
    expect(completed, 0);
    expect(find.text('Turn off'), findsOneWidget);
  });
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd apps/amuwak_staff && flutter test test/auth/mfa_enrolment_screen_test.dart --timeout=none
```

Expected: FAIL — no `Replace recovery codes` widget.

- [ ] **Step 3: Add the action to the enrolled view**

In `_enrolledBody`, insert above the existing `Turn off` button:

```dart
        OutlinedButton(
          onPressed: _busy ? null : _replaceRecoveryCodes,
          child: const Text('Replace recovery codes'),
        ),
        const SizedBox(height: AppSpacing.sm),
```

and add:

```dart
  /// A fresh set, invalidating the old one. Distinct from [_turnOff]: two-factor
  /// stays on, so this must not report completion.
  Future<void> _replaceRecoveryCodes() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => RecoveryCodesScreen(
          onAcknowledged: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd apps/amuwak_staff && flutter test test/auth/mfa_enrolment_screen_test.dart --timeout=none
```

Expected: all PASS.

- [ ] **Step 5: Full verification**

```bash
cd packages/amuwak_core && flutter analyze && flutter test --timeout=none
cd apps/amuwak_staff && flutter analyze && flutter test --timeout=none
```

Expected: analyze clean on both; core and staff suites green. Do not edit any file while these run — a mid-run edit makes the suite report failures against half-applied changes.

- [ ] **Step 6: Commit**

```bash
git add apps/amuwak_staff/lib/src/auth/mfa_enrolment_screen.dart \
        apps/amuwak_staff/test/auth/mfa_enrolment_screen_test.dart
git commit -F <message-file>
```

Message: `feat(staff): replace recovery codes from Account`

---

## Deliberate deviations from the spec

Two, both recorded here so a reviewer can overrule them rather than discover them.

**1. Code alphabet is hex, not Crockford base32.** The spec said base32.
Postgres has no base32 encoder, so that meant writing and testing one for no
security gain. `encode(gen_random_bytes(10), 'hex')` is built in and verified
working against the live DB. **The entropy is unchanged at 80 bits** — only the
alphabet differs, and hex has no ambiguous character pairs. Codes are 20
characters instead of 16.

**2. No "Two-factor is now off" dashboard notice.** The spec called for one after
redemption. Delivering it means threading state across the `AuthGate` boundary as
the challenge screen unmounts — real complexity for a message the user has
already been given. Two signals cover it instead:

- the recovery form says so *before* they commit: "Using one switches two-factor
  off until you set it up again";
- the Account card reads `Off` immediately afterwards. This needs no new code —
  `mfaEnabledProvider` watches `authStateProvider`, and the `refreshSession()`
  in Task 6 emits `tokenRefreshed`, so the card recomputes on its own.

Telling someone before they act beats telling them after.

## Deployment (cannot be done from here)

1. `supabase db push` — applies 0054 to the remote project.
2. `supabase functions deploy redeem-recovery-code`.
3. Manual end-to-end check, which is the only real verification the Edge Function gets:
   - enrol a test staff account, save the codes;
   - sign out, sign back in, and at the challenge use a recovery code;
   - confirm the dashboard opens and Account reads `Off`;
   - confirm the same code is refused a second time.
