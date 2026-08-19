# Rate Override Fix (S0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a customer's standing per-kg rate editable by a manager, and make every per-order rate override accountable — recorded with the rate it replaced, a reason, and a configurable floor below which only a manager may go.

**Architecture:** Three gaps close together. (1) `customers.custom_rate_per_kg_ugx` is today write-once at customer creation and unreachable afterward — the customer form gets a manager-gated field for it. (2) The per-order override in New Pickup already works but is anonymous — two new `orders` columns record what it replaced and why. (3) Nothing bounds how low a rider may price an order — a new `pricing_settings.min_rate_pct_of_default` sets a floor, enforced client-side for UX and inside `create_pickup` as the real boundary.

**Tech Stack:** Flutter 3.32 / Dart 3.8, Riverpod, Drift (local mirror + outbox), Supabase Postgres with RLS, pgTAP for DB tests, `flutter_test` + `mocktail`.

**Spec:** [docs/superpowers/specs/2026-08-17-subscription-packages-design.md](../specs/2026-08-17-subscription-packages-design.md) — Part 6, "The companion rate-override fix".

### Deliberate deviation from the spec

Part 6 item 2 says the audit is a `rate_override_audit` table. **This plan puts the audit on `orders` as two columns instead** (`rate_override_reason`, `rate_override_from_ugx`).

Reason: New Pickup is offline-first. An order is written to the local Drift DB and the `create_pickup` RPC is queued on the outbox. A separate audit table would need its own Drift table, its own outbox op type, its own handler, and its own idempotency story — and could still desynchronise from the order it describes if one drained and the other didn't. Two columns on the row being audited ride the existing atomic `create_pickup` path and cannot separate from it. The spec's Part 6 should be updated to match once this lands.

## Global Constraints

- **UGX has no minor units.** Integer shillings throughout. Rates are stored `numeric` (the existing `rate_per_kg_snapshot_ugx` type) but always rounded to whole UGX before persisting, matching `new_pickup_screen.dart:454`.
- **Next free migration number is `0059`.** Re-derive with `ls supabase/migrations | tail -1` before writing — this repo has a history of prefix collisions.
- **Grants invariant (0057):** the verbs a table grants `authenticated` must equal the verbs its RLS policies name. New columns on existing tables inherit that table's grants; no new grant statements are needed in this plan because no new table is created.
- **Drift `schemaVersion` is 9** (`apps/amuwak_staff/lib/src/data/app_database.dart:32`). Any local column addition bumps it to 10 with a matching `onUpgrade` step.
- **Run `flutter test` one file at a time.** `flutter test path1 path2` hangs at "loading" on this Windows host. A `+0 -1` timeout on the `loading` line is the host, not the code — retry, or add `--timeout=none`.
- **Coverage target is 98%** on testable surface via `bash coverage/summary.sh`. The repo currently sits at 99.14%; do not regress it.
- **Commit with explicit paths** — the working tree may hold unrelated staged work, and a bare `git commit` would sweep it in. Use `git commit -F`, never `-m`: PowerShell drops double quotes from `-m`, and `Set-Content -Encoding utf8` double-encodes em dashes. The working pattern, used verbatim at every commit step below (substitute the message and paths):

  ```powershell
  [System.IO.File]::WriteAllText("$env:TEMP\msg.txt", "feat(scope): subject line")
  git add <paths>
  git commit -F "$env:TEMP\msg.txt" -- <paths>
  ```
- **Role strings:** manager is `'manager'`. Customer create/edit is already gated to `{'in_shop', 'manager'}` (`staff_dashboard_screen.dart:765`). Rate editing is **manager-only** — a narrower gate.

---

## File Structure

| File | Responsibility |
|---|---|
| `supabase/migrations/0059_rate_override_audit.sql` | Two `orders` audit columns, the `pricing_settings` floor column, `create_pickup` threading + floor enforcement |
| `supabase/tests/0059_rate_override_audit_test.sql` | pgTAP: columns exist with right defaults; `create_pickup` rejects a sub-floor rate from a driver |
| `packages/amuwak_core/lib/src/pricing/rate_floor.dart` | Pure floor arithmetic and the allow/deny predicate. No I/O |
| `packages/amuwak_core/lib/src/pricing/pricing_settings.dart` | Gains `minRatePctOfDefault` |
| `packages/amuwak_core/lib/src/orders/order.dart` | `LaundryOrder` gains `rateOverrideReason`, `rateOverrideFromUgx` |
| `packages/amuwak_core/lib/src/sync/supabase_payloads.dart` | Serialises the two new order fields |
| `apps/amuwak_staff/lib/src/data/tables/orders_table.dart` | Drift mirror of the two columns |
| `apps/amuwak_staff/lib/src/data/app_database.dart` | `schemaVersion` 9 → 10 + upgrade step |
| `apps/amuwak_staff/lib/src/sync/supabase_mappers.dart` | Reads the two columns back off a synced row |
| `apps/amuwak_staff/lib/src/customers/customer_form_screen.dart` | Manager-gated standing-rate field |
| `apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart` | Passes the manager gate into the customer form |
| `apps/amuwak_staff/lib/src/orders/new_pickup_screen.dart` | Reason field, floor validation, populates the audit columns |

---

## Task 1: Migration 0059 — audit columns, rate floor, `create_pickup` threading

**Files:**
- Create: `supabase/migrations/0059_rate_override_audit.sql`
- Create: `supabase/tests/0059_rate_override_audit_test.sql`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: `orders.rate_override_reason text`, `orders.rate_override_from_ugx numeric`, `pricing_settings.min_rate_pct_of_default integer NOT NULL DEFAULT 0`. `create_pickup(p_customer jsonb, p_order jsonb)` keeps its signature and now raises `'rate_below_floor'` when a non-manager sends a rate under the floor.

- [ ] **Step 1: Confirm the migration number**

Run: `ls supabase/migrations | tail -3`

Expected: the highest prefix is `0058`. If it is not, use `<highest + 1>` everywhere below instead of `0059`, including both filenames.

- [ ] **Step 2: Write the failing pgTAP test**

Create `supabase/tests/0059_rate_override_audit_test.sql`:

```sql
-- 0059_rate_override_audit_test.sql
-- The two order audit columns and the pricing floor exist, and create_pickup
-- refuses a sub-floor rate from a driver while allowing it from a manager.
BEGIN;
SELECT plan(6);

SELECT has_column('public', 'orders', 'rate_override_reason',
  'orders carries the reason a rate override was applied');
SELECT has_column('public', 'orders', 'rate_override_from_ugx',
  'orders carries the rate the override replaced');
SELECT has_column('public', 'pricing_settings', 'min_rate_pct_of_default',
  'pricing_settings carries the override floor');

SELECT col_default_is('public', 'pricing_settings', 'min_rate_pct_of_default',
  '0', 'the floor defaults to 0, i.e. disabled, so existing rows are unaffected');

SELECT col_is_null('public', 'orders', 'rate_override_reason',
  'the reason is nullable — most orders are not overridden');

-- The floor is enforced inside create_pickup, not by a CHECK, because it
-- compares against a value in another table and exempts managers.
SELECT function_returns('public', 'create_pickup',
  ARRAY['jsonb', 'jsonb'], 'jsonb',
  'create_pickup keeps its signature after CREATE OR REPLACE');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `supabase start -x storage-api,imgproxy --ignore-health-check` then `supabase test db`

Expected: `0059_rate_override_audit_test.sql` FAILS — `has_column` reports the columns do not exist.

Note: `0015_powersync` fails 15/15 as a pre-existing condition. A non-zero exit from `supabase test db` is only your regression if `0059_...` is among the failures after Step 5.

- [ ] **Step 4: Write the migration**

Create `supabase/migrations/0059_rate_override_audit.sql`:

```sql
-- 0059_rate_override_audit.sql
-- Makes a per-order rate override accountable, and bounds how low one can go.
--
-- Until now any rider could type any rate into New Pickup and the order simply
-- billed at it, with nothing recorded about what it replaced or why. Two
-- columns on `orders` close that: the rate that would otherwise have applied,
-- and a free-text reason.
--
-- The audit lives on `orders` rather than in its own table on purpose. New
-- Pickup is offline-first: the order is written to a local Drift DB and the
-- create_pickup RPC is queued on the outbox. A separate audit table would need
-- its own outbox op and could drain independently of the order it describes.
-- Columns on the audited row cannot desynchronise from it.
--
-- `min_rate_pct_of_default` is the floor, as a whole percentage of the global
-- default rate. 0 disables it, which is the default so this migration changes
-- no existing behaviour until a manager sets a value.
--
-- The floor is enforced inside create_pickup rather than as a CHECK constraint:
-- it compares against a value in another table, and managers are exempt.
-- create_pickup is already the only path a rider has into `orders`.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS rate_override_reason   text,
  ADD COLUMN IF NOT EXISTS rate_override_from_ugx numeric;

ALTER TABLE pricing_settings
  ADD COLUMN IF NOT EXISTS min_rate_pct_of_default integer NOT NULL DEFAULT 0
    CHECK (min_rate_pct_of_default >= 0 AND min_rate_pct_of_default <= 100);

-- CREATE OR REPLACE keeps the existing EXECUTE grants (authenticated), so they
-- are not re-issued. Verbatim copy of the 0058 body with:
--   1. the two audit columns threaded through the explicit INSERT column list
--      (the function does not pass p_order through generically, so a new column
--      is silently dropped on create until it is named here), and
--   2. the floor check added before the INSERT.
CREATE OR REPLACE FUNCTION create_pickup(p_customer jsonb, p_order jsonb)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_caller      uuid := auth.uid();
  v_role        text := auth_staff_role();
  v_customer_id uuid := (p_customer->>'id')::uuid;
  v_order_id    uuid := (p_order->>'id')::uuid;
  v_code        text;
  v_assigned    uuid;
  v_rate        numeric := COALESCE((p_order->>'rate_per_kg_snapshot_ugx')::numeric, 0);
  v_floor       numeric;
BEGIN
  IF v_caller IS NULL OR v_role IS NULL THEN
    RAISE EXCEPTION 'create_pickup requires an active staff caller';
  END IF;
  IF v_customer_id IS NULL OR v_order_id IS NULL THEN
    RAISE EXCEPTION 'create_pickup requires customer id and order id';
  END IF;

  -- Rate floor. Managers are exempt; 0 or no settings row disables it.
  IF v_role <> 'manager' AND v_rate > 0 THEN
    SELECT default_rate_per_kg_ugx * min_rate_pct_of_default / 100.0
      INTO v_floor FROM pricing_settings LIMIT 1;
    IF v_floor IS NOT NULL AND v_floor > 0 AND v_rate < v_floor THEN
      RAISE EXCEPTION 'rate_below_floor'
        USING DETAIL = format('rate %s is below the floor of %s', v_rate, v_floor);
    END IF;
  END IF;
```

Then **copy lines 39 through 104 of `supabase/migrations/0058_orders_expected_collection.sql` verbatim** — from the `-- Upsert the customer` comment down to and including `$$;` — appending them to the block above, with exactly two edits:

1. In the `INSERT INTO orders (...)` column list, after the line `scheduled_for, expected_collection_at,`, add:
   ```sql
   rate_override_reason, rate_override_from_ugx,
   ```
2. In the matching `VALUES (...)` list, after the line `(p_order->>'expected_collection_at')::timestamptz,`, add:
   ```sql
   p_order->>'rate_override_reason',
   (p_order->>'rate_override_from_ugx')::numeric,
   ```

The two lists are positional — an addition to one without the other is a column-count error, so verify both edits before running.

- [ ] **Step 5: Run the test to verify it passes**

Run: `supabase test db`

Expected: `0059_rate_override_audit_test.sql` reports `ok 1` through `ok 6`. `0015_powersync` still fails 15/15 — that is pre-existing and not your regression.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0059_rate_override_audit.sql supabase/tests/0059_rate_override_audit_test.sql
git commit -F "$env:TEMP\msg.txt" -- supabase/migrations/0059_rate_override_audit.sql supabase/tests/0059_rate_override_audit_test.sql
```

Message: `feat(pricing): record rate overrides on the order and bound them by a floor`

---

## Task 2: Core — floor arithmetic, settings field, order audit fields

**Files:**
- Create: `packages/amuwak_core/lib/src/pricing/rate_floor.dart`
- Create: `packages/amuwak_core/test/pricing/rate_floor_test.dart`
- Modify: `packages/amuwak_core/lib/src/pricing/pricing_settings.dart`
- Modify: `packages/amuwak_core/lib/src/orders/order.dart`
- Modify: `packages/amuwak_core/lib/src/sync/supabase_payloads.dart`

**Interfaces:**
- Consumes: Task 1's columns (`min_rate_pct_of_default`, `rate_override_reason`, `rate_override_from_ugx`)
- Produces:
  - `int rateFloorUgx({required double defaultRateUgx, required int minRatePct})`
  - `bool isRateAllowed({required double rateUgx, required int floorUgx, required bool isManager})`
  - `PricingSettings.minRatePctOfDefault` (`int`, default `0`)
  - `LaundryOrder.rateOverrideReason` (`String?`), `LaundryOrder.rateOverrideFromUgx` (`double?`)

- [ ] **Step 1: Write the failing test**

Create `packages/amuwak_core/test/pricing/rate_floor_test.dart`:

```dart
import 'package:amuwak_core/amuwak_core.dart';
import 'package:test/test.dart';

void main() {
  group('rateFloorUgx', () {
    test('returns the whole-shilling percentage of the default rate', () {
      expect(rateFloorUgx(defaultRateUgx: 5000, minRatePct: 60), 3000);
    });

    test('rounds to whole UGX because shillings have no minor units', () {
      // 4999 * 60% = 2999.4
      expect(rateFloorUgx(defaultRateUgx: 4999, minRatePct: 60), 2999);
    });

    test('a percentage of 0 disables the floor', () {
      expect(rateFloorUgx(defaultRateUgx: 5000, minRatePct: 0), 0);
    });

    test('a negative percentage is treated as disabled, never as a raise', () {
      expect(rateFloorUgx(defaultRateUgx: 5000, minRatePct: -10), 0);
    });
  });

  group('isRateAllowed', () {
    test('permits a rate at or above the floor', () {
      expect(isRateAllowed(rateUgx: 3000, floorUgx: 3000, isManager: false),
          isTrue);
    });

    test('refuses a rate below the floor for a non-manager', () {
      expect(isRateAllowed(rateUgx: 2999, floorUgx: 3000, isManager: false),
          isFalse);
    });

    test('a manager is exempt from the floor', () {
      expect(
          isRateAllowed(rateUgx: 1, floorUgx: 3000, isManager: true), isTrue);
    });

    test('a floor of 0 permits anything', () {
      expect(
          isRateAllowed(rateUgx: 1, floorUgx: 0, isManager: false), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/amuwak_core && dart test test/pricing/rate_floor_test.dart`

Expected: FAIL — `rateFloorUgx` and `isRateAllowed` are not defined.

- [ ] **Step 3: Write the implementation**

Create `packages/amuwak_core/lib/src/pricing/rate_floor.dart`:

```dart
/// The lowest per-kg rate a non-manager may bill an order at.
///
/// [minRatePct] is a whole percentage of [defaultRateUgx] — 60 means "no lower
/// than 60% of the default rate". 0 (or anything below it) disables the floor
/// entirely, which is the shipped default so existing installations are
/// unaffected until a manager sets a value.
///
/// Rounded to whole shillings: UGX has no minor units, and the floor is
/// compared against rates that are themselves rounded before persisting.
int rateFloorUgx({required double defaultRateUgx, required int minRatePct}) {
  if (minRatePct <= 0) return 0;
  return (defaultRateUgx * minRatePct / 100).round();
}

/// Whether [rateUgx] may be billed given [floorUgx].
///
/// A manager is always exempt — the floor exists to bound what a rider can do
/// unilaterally, not to stop the business from pricing as it chooses. A floor
/// of 0 is disabled and permits anything.
bool isRateAllowed({
  required double rateUgx,
  required int floorUgx,
  required bool isManager,
}) =>
    isManager || floorUgx <= 0 || rateUgx >= floorUgx;
```

Export it from the package barrel — add to `packages/amuwak_core/lib/amuwak_core.dart`, beside the other `src/pricing/` exports:

```dart
export 'src/pricing/rate_floor.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd packages/amuwak_core && dart test test/pricing/rate_floor_test.dart`

Expected: PASS, 8 tests.

- [ ] **Step 5: Add `minRatePctOfDefault` to `PricingSettings`**

In `packages/amuwak_core/lib/src/pricing/pricing_settings.dart`:

Add to the constructor parameter list, after `this.freeDeliveryThresholdUgx = 0,`:
```dart
    this.minRatePctOfDefault = 0,
```

Add the field, after `freeDeliveryThresholdUgx`:
```dart
  /// Floor for a per-order rate override, as a whole percentage of
  /// [defaultRatePerKgUgx]. 0 disables it. Managers are exempt — see
  /// [isRateAllowed]. Enforced for real inside the `create_pickup` RPC;
  /// the client check is UX only.
  final int minRatePctOfDefault;
```

Add to `fromSupabase`, following the existing null-degrade style so a row predating the column cannot error the read:
```dart
        minRatePctOfDefault:
            (r['min_rate_pct_of_default'] as num?)?.toInt() ?? 0,
```

Add to `copyWith`'s parameters and body in the same positions as the neighbouring `int?` fields.

- [ ] **Step 6: Add the audit fields to `LaundryOrder`**

In `packages/amuwak_core/lib/src/orders/order.dart`, add to the constructor after `this.ratePerKgSnapshotUgx = 0,`:
```dart
    this.rateOverrideReason,
    this.rateOverrideFromUgx,
```

And the fields, after `ratePerKgSnapshotUgx`:
```dart
  /// Why this order was billed at a rate other than the one that would
  /// otherwise apply. Null on the overwhelming majority of orders.
  final String? rateOverrideReason;

  /// The rate that would have applied without the override — the customer's
  /// standing rate, or the global default. Null when no override was made.
  /// Stored so the audit is readable without re-deriving what pricing looked
  /// like at the time. See Supabase migration 0059.
  final double? rateOverrideFromUgx;
```

Add both to `copyWith` in the same style as the surrounding nullable fields.

- [ ] **Step 7: Serialise them**

In `packages/amuwak_core/lib/src/sync/supabase_payloads.dart`, after the `'rate_per_kg_snapshot_ugx'` entry:
```dart
      'rate_override_reason': order.rateOverrideReason,
      'rate_override_from_ugx': order.rateOverrideFromUgx,
```

- [ ] **Step 8: Run the core suite to verify nothing regressed**

Run: `cd packages/amuwak_core && dart test`

Expected: PASS. New optional fields with defaults break no existing construction.

- [ ] **Step 9: Commit**

```bash
git add packages/amuwak_core/
git commit -F "$env:TEMP\msg.txt" -- packages/amuwak_core/
```

Message: `feat(core): rate floor arithmetic and order rate-override audit fields`

---

## Task 3: Drift mirror for the audit columns

**Files:**
- Modify: `apps/amuwak_staff/lib/src/data/tables/orders_table.dart`
- Modify: `apps/amuwak_staff/lib/src/data/app_database.dart`
- Modify: `apps/amuwak_staff/lib/src/sync/supabase_mappers.dart`
- Test: `apps/amuwak_staff/test/data/app_database_migration_test.dart` (modify if present; create if not)

**Interfaces:**
- Consumes: Task 2's `LaundryOrder.rateOverrideReason` / `rateOverrideFromUgx`
- Produces: Drift columns `rateOverrideReason` (`TextColumn`, nullable) and `rateOverrideFromUgx` (`RealColumn`, nullable) on the orders table; `schemaVersion` 10.

- [ ] **Step 1: Write the failing migration test**

In `apps/amuwak_staff/test/data/app_database_migration_test.dart`, add:

```dart
  test('v9 to v10 adds the rate-override audit columns and keeps existing rows',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // A row written before the columns existed must survive the upgrade with
    // both new columns null — an override is the exception, not the default.
    await db.customStatement('PRAGMA user_version = 10');
    final cols = await db
        .customSelect('PRAGMA table_info(orders)')
        .get()
        .then((rows) => rows.map((r) => r.data['name'] as String).toSet());

    expect(cols, contains('rate_override_reason'));
    expect(cols, contains('rate_override_from_ugx'));
  });
```

If the file does not exist, create it with the imports the sibling tests in `apps/amuwak_staff/test/data/` use (`package:drift/native.dart`, `package:amuwak_staff/src/data/app_database.dart`, `package:flutter_test/flutter_test.dart`) and a `void main()` wrapper.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd apps/amuwak_staff && flutter test test/data/app_database_migration_test.dart`

Expected: FAIL — the columns are absent from `PRAGMA table_info(orders)`.

- [ ] **Step 3: Add the columns to the Drift table**

In `apps/amuwak_staff/lib/src/data/tables/orders_table.dart`, beside the existing rate column:

```dart
  TextColumn get rateOverrideReason =>
      text().named('rate_override_reason').nullable()();
  RealColumn get rateOverrideFromUgx =>
      real().named('rate_override_from_ugx').nullable()();
```

- [ ] **Step 4: Bump the schema version and add the upgrade step**

In `apps/amuwak_staff/lib/src/data/app_database.dart`, change line 32:

```dart
  int get schemaVersion => 10;
```

And in the `onUpgrade` migration chain, following the existing `addColumn` style:

```dart
        if (from < 10) {
          await m.addColumn(orders, orders.rateOverrideReason);
          await m.addColumn(orders, orders.rateOverrideFromUgx);
        }
```

- [ ] **Step 5: Regenerate the Drift code**

Run: `cd apps/amuwak_staff && dart run build_runner build --delete-conflicting-outputs`

Expected: `app_database.g.dart` regenerates with both columns. Do not hand-edit the `.g.dart`.

- [ ] **Step 6: Map the columns back off a synced row**

In `apps/amuwak_staff/lib/src/sync/supabase_mappers.dart`, in the orders mapper beside `ratePerKgSnapshotUgx`:

```dart
      rateOverrideReason: r['rate_override_reason'] as String?,
      rateOverrideFromUgx: (r['rate_override_from_ugx'] as num?)?.toDouble(),
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd apps/amuwak_staff && flutter test test/data/app_database_migration_test.dart`

Expected: PASS.

Then run the sync mapper tests: `flutter test test/sync/` — one file at a time if it hangs on `loading`.

- [ ] **Step 8: Commit**

```bash
git add apps/amuwak_staff/lib/src/data/ apps/amuwak_staff/lib/src/sync/supabase_mappers.dart apps/amuwak_staff/test/data/
git commit -F "$env:TEMP\msg.txt" -- apps/amuwak_staff/lib/src/data/ apps/amuwak_staff/lib/src/sync/supabase_mappers.dart apps/amuwak_staff/test/data/
```

Message: `feat(staff): mirror the rate-override audit columns in Drift`

---

## Task 4: Manager-gated standing rate on the customer form

**Files:**
- Modify: `apps/amuwak_staff/lib/src/customers/customer_form_screen.dart`
- Modify: `apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart:645`
- Test: `apps/amuwak_staff/test/customers/customer_form_screen_test.dart`

**Interfaces:**
- Consumes: Task 2's `rateFloorUgx` / `isRateAllowed`, `PricingSettings.minRatePctOfDefault`
- Produces: `CustomerFormScreen({..., bool canEditRate = false, double defaultRatePerKgUgx = 0, int minRatePctOfDefault = 0})`. Field key `Key('customer_rate')`. There is no separate clear button — emptying the field clears the override.

`canEditRate` defaults to `false` so the four existing tests in the file compile and pass unchanged.

**First, extend the test helper.** `_customer(...)` at the top of the test file hardcodes `customRatePerKgUgx: null`. Add a parameter so a customer with an existing rate can be built without Drift's `Value` wrapper:

```dart
Customer _customer({
  required String id,
  required String name,
  required String phone,
  DateTime? createdAt,
  double? customRatePerKgUgx,          // <-- add
}) =>
    Customer(
      // ...unchanged...
      customRatePerKgUgx: customRatePerKgUgx,   // <-- was: null
      // ...unchanged...
    );
```

- [ ] **Step 1: Write the failing tests**

Append to `apps/amuwak_staff/test/customers/customer_form_screen_test.dart`:

```dart
  testWidgets('hides the rate field when the user cannot edit rates',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(save: (c) async {}),
    ));

    expect(find.byKey(const Key('customer_rate')), findsNothing);
  });

  testWidgets('a manager can set a standing rate on an existing customer',
      (tester) async {
    Customer? saved;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        existing: _customer(id: 'keep-id', name: 'Ada', phone: '0700123456'),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
        clock: () => DateTime.utc(2026, 8, 17),
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_rate')), '4000');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved!.customRatePerKgUgx, 4000.0,
        reason: 'this is the gap S0 closes — the rate was previously '
            'unreachable once the customer existed');
  });

  testWidgets('a manager can clear a standing rate back to the default',
      (tester) async {
    Customer? saved;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        existing: _customer(
            id: 'keep-id',
            name: 'Ada',
            phone: '0700123456',
            customRatePerKgUgx: 4000),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_rate')), '');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved!.customRatePerKgUgx, isNull,
        reason: 'an emptied field clears the override rather than keeping the '
            'old value');
  });

  testWidgets('a fractional rate is rounded to whole shillings',
      (tester) async {
    Customer? saved;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => saved = c,
        existing: _customer(id: 'keep-id', name: 'Ada', phone: '0700123456'),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_rate')), '4000.7');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(saved!.customRatePerKgUgx, 4001.0);
  });

  testWidgets('refuses a rate below the configured floor', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: CustomerFormScreen(
        save: (c) async => calls++,
        existing: _customer(id: 'keep-id', name: 'Ada', phone: '0700123456'),
        canEditRate: true,
        defaultRatePerKgUgx: 5000,
        minRatePctOfDefault: 60, // floor = 3000
      ),
    ));

    await tester.enterText(find.byKey(const Key('customer_rate')), '2000');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(calls, 0);
    expect(find.textContaining('below the minimum'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/amuwak_staff && flutter test test/customers/customer_form_screen_test.dart`

Expected: FAIL — `canEditRate` is not a named parameter of `CustomerFormScreen`.

- [ ] **Step 3: Add the parameters and the field**

In `apps/amuwak_staff/lib/src/customers/customer_form_screen.dart`, add to the constructor and fields:

```dart
    this.canEditRate = false,
    this.defaultRatePerKgUgx = 0,
    this.minRatePctOfDefault = 0,
```
```dart
  /// Whether this user may set the customer's standing per-kg rate. Manager-only
  /// — narrower than the {in_shop, manager} gate on creating customers at all,
  /// because this is a pricing decision rather than a CRM one.
  final bool canEditRate;

  /// The global default, shown as the hint when no override is set.
  final double defaultRatePerKgUgx;

  /// Floor as a whole percentage of [defaultRatePerKgUgx]; 0 disables it.
  final int minRatePctOfDefault;
```

Add the controller beside the others:

```dart
  late final _rateController = TextEditingController(
    text: widget.existing?.customRatePerKgUgx?.round().toString() ?? '',
  );
```

Dispose it in `dispose()`, alongside the existing four.

- [ ] **Step 4: Parse, validate and save the rate**

Replace the pinned assignment at `customer_form_screen.dart:80-82`:

```dart
      // Editing never touches the standing per-kg rate here; it's managed from
      // pricing. A brand-new customer starts without an override.
      customRatePerKgUgx: widget.existing?.customRatePerKgUgx,
```

with:

```dart
      // A manager may set or clear the standing rate here; anyone else leaves it
      // exactly as found. Before migration 0059 this was pinned, which meant a
      // rate set at customer creation could never be changed again.
      customRatePerKgUgx: widget.canEditRate
          ? rate
          : widget.existing?.customRatePerKgUgx,
```

And insert this validation block in `_save()` immediately before `final now = widget.clock();`:

```dart
    // An emptied field clears the override; a filled one is rounded to whole
    // shillings, matching how New Pickup and the settings screen persist rates.
    double? rate = widget.existing?.customRatePerKgUgx;
    if (widget.canEditRate) {
      final raw = _rateController.text.trim();
      if (raw.isEmpty) {
        rate = null;
      } else {
        final parsed = double.tryParse(raw)?.roundToDouble();
        if (parsed == null || parsed <= 0) {
          _showError('Enter a rate greater than 0, or clear it to use the default.');
          return;
        }
        final floor = rateFloorUgx(
          defaultRateUgx: widget.defaultRatePerKgUgx,
          minRatePct: widget.minRatePctOfDefault,
        );
        // isManager: false — this form is only reachable by a manager, so the
        // floor it shows is the one riders will be held to. A manager who needs
        // to go lower changes the floor, which is an auditable settings change
        // rather than a silent per-customer exception.
        if (!isRateAllowed(rateUgx: parsed, floorUgx: floor, isManager: false)) {
          _showError('That is below the minimum of ${formatUgx(floor)}/kg.');
          return;
        }
        rate = parsed;
      }
    }
```

- [ ] **Step 5: Render the field**

In `build`, between the Notes field and the save button:

```dart
            if (canEditRateField) ...[
              const SizedBox(height: AppSpacing.lg),
              _Field(
                label: 'Standing rate (USh/kg) — blank uses the default'
                    '${widget.defaultRatePerKgUgx > 0 ? ' of ${formatUgx(widget.defaultRatePerKgUgx.round())}' : ''}',
                controller: _rateController,
                fieldKey: const Key('customer_rate'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
```

with `bool get canEditRateField => widget.canEditRate;` — or inline `widget.canEditRate` directly. Import `formatUgx`, `rateFloorUgx` and `isRateAllowed` via the existing `package:amuwak_core/amuwak_core.dart` import already at the top of the file.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd apps/amuwak_staff && flutter test test/customers/customer_form_screen_test.dart`

Expected: PASS — nine tests (four pre-existing, five new).

- [ ] **Step 7: Wire the dashboard**

In `apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart`, in `_openCustomerForm` at line 645, add to the `CustomerFormScreen(...)` construction:

First, read the settings once at the top of `_openCustomerForm`, beside the existing `repo` read. `pricingSettingsProvider` is already imported and used in this file (lines 213 and 473), so no new import is needed:

```dart
    final settings = ref.read(pricingSettingsProvider).valueOrNull;
```

Then add to the `CustomerFormScreen(...)` construction at line 645:

```dart
          canEditRate: ref.read(currentRoleProvider) == 'manager',
          defaultRatePerKgUgx: settings?.defaultRatePerKgUgx ?? 0,
          minRatePctOfDefault: settings?.minRatePctOfDefault ?? 0,
```

A null settings value degrades to a disabled floor and a 0 default-rate hint — the form still saves, it just cannot show or enforce a floor. That matches how the rest of this screen treats an unloaded settings row.

- [ ] **Step 8: Run the dashboard tests**

Run: `cd apps/amuwak_staff && flutter test test/dashboard/staff_dashboard_screen_test.dart`

Expected: PASS. The two tests that assert `find.byType(CustomerFormScreen)` still find it; the rate field is simply hidden for non-managers.

- [ ] **Step 9: Commit**

```bash
git add apps/amuwak_staff/lib/src/customers/customer_form_screen.dart apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart apps/amuwak_staff/test/customers/customer_form_screen_test.dart
git commit -F "$env:TEMP\msg.txt" -- apps/amuwak_staff/lib/src/customers/customer_form_screen.dart apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart apps/amuwak_staff/test/customers/customer_form_screen_test.dart
```

Message: `feat(customers): let a manager set and clear a standing per-kg rate`

---

## Task 5: New Pickup — reason, floor, and populating the audit

**Files:**
- Modify: `apps/amuwak_staff/lib/src/orders/new_pickup_screen.dart`
- Test: `apps/amuwak_staff/test/orders/new_pickup_custom_rate_test.dart`

**Interfaces:**
- Consumes: Task 2's `rateFloorUgx` / `isRateAllowed` and `LaundryOrder.rateOverrideReason` / `rateOverrideFromUgx`; Task 3's Drift columns
- Produces: `NewPickupScreen({..., int minRatePctOfDefault = 0, bool isManager = false})`. Reason field key `Key('np_rate_reason')`.

Both new parameters default to the permissive value so the five existing tests in `new_pickup_custom_rate_test.dart` and the tests in `new_pickup_rate_test.dart` compile and pass unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `apps/amuwak_staff/test/orders/new_pickup_custom_rate_test.dart`. Note `pumpFormAndOpen` currently hard-codes the screen's parameters — give it two optional arguments first:

```dart
  Future<_FormHandle> pumpFormAndOpen(
    WidgetTester tester, {
    int minRatePctOfDefault = 0,
    bool isManager = false,
  }) async {
```

and pass them through to `NewPickupScreen(...)` beside `defaultRatePerKgUgx: 5000`. Then add:

```dart
  testWidgets('a typed override records what it replaced and why',
      (tester) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('np_custom_rate')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('np_custom_rate')), '4000');
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('np_rate_reason')), 'Bulk hostel deal');

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final order = capturedPickup().order;
    expect(order.ratePerKgSnapshotUgx, 4000.0);
    expect(order.rateOverrideFromUgx, 5000.0,
        reason: 'the audit records the default it replaced');
    expect(order.rateOverrideReason, 'Bulk hostel deal');
  });

  testWidgets('an order with no override leaves the audit fields null',
      (tester) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    final order = capturedPickup().order;
    expect(order.rateOverrideFromUgx, isNull);
    expect(order.rateOverrideReason, isNull);
  });

  testWidgets('a rider cannot submit an override below the floor',
      (tester) async {
    // default 5000, floor 60% = 3000.
    await pumpFormAndOpen(tester, minRatePctOfDefault: 60);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('np_custom_rate')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('np_custom_rate')), '2000');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('np_rate_reason')), 'Discount');

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pump();

    verifyNever(() => ordersRepo.createPickup(any(), any(),
        actorStaffId: any(named: 'actorStaffId')));
    expect(find.textContaining('below the minimum'), findsOneWidget);
  });

  testWidgets('a manager may go below the floor', (tester) async {
    await pumpFormAndOpen(tester, minRatePctOfDefault: 60, isManager: true);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('np_custom_rate')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('np_custom_rate')), '2000');
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('np_rate_reason')), 'Manager approved');

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pumpAndSettle();

    expect(capturedPickup().order.ratePerKgSnapshotUgx, 2000.0);
  });

  testWidgets('an override without a reason is refused', (tester) async {
    await pumpFormAndOpen(tester);

    await tester.enterText(find.byKey(const Key('np_name')), 'Jane Doe');
    await tester.enterText(
        find.byKey(const Key('np_phone')), '+256 700 111 222');
    await tester.enterText(
        find.byKey(const Key('np_address')), 'Kikoni, Kampala');
    await tester.tap(find.byKey(const Key('np_service_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceType.washAndIron.label).last);
    await tester.pumpAndSettle();
    await setCount(tester, 3);

    await tester.dragUntilVisible(
      find.text('Add optional details'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Add optional details'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('np_custom_rate')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byKey(const Key('np_custom_rate')), '4000');
    await tester.pump();
    // Reason deliberately left blank.

    await tester.dragUntilVisible(
      find.widgetWithText(ElevatedButton, 'Create pickup'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create pickup'));
    await tester.pump();

    verifyNever(() => ordersRepo.createPickup(any(), any(),
        actorStaffId: any(named: 'actorStaffId')));
    expect(find.textContaining('Say why'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd apps/amuwak_staff && flutter test test/orders/new_pickup_custom_rate_test.dart`

Expected: FAIL — `minRatePctOfDefault` is not a named parameter of `NewPickupScreen`.

- [ ] **Step 3: Add the parameters and the reason controller**

In `apps/amuwak_staff/lib/src/orders/new_pickup_screen.dart`, add to the widget's constructor and fields, beside `defaultRatePerKgUgx`:

```dart
    this.minRatePctOfDefault = 0,
    this.isManager = false,
```
```dart
  /// Floor for a typed override, as a whole percentage of
  /// [defaultRatePerKgUgx]. 0 disables it — the shipped default, so nothing
  /// changes until a manager configures one.
  final int minRatePctOfDefault;

  /// Managers are exempt from the floor. The server enforces this too, in
  /// `create_pickup`; this check exists so the rider learns before the order is
  /// queued rather than after the outbox rejects it.
  final bool isManager;
```

Add the controller beside `_customRateController` at line 117:

```dart
  final _rateReasonController = TextEditingController();
```

Dispose it beside `_customRateController.dispose()` at line 566.

- [ ] **Step 4: Add the derived values**

Beside the existing `_resolvedRate` getter at line 155:

```dart
  /// The rate that would apply with no typed override — the matched customer's
  /// standing rate, or the global default. This is what an override replaces,
  /// and what gets recorded as `rateOverrideFromUgx`.
  double get _baseRate =>
      _matchedCustomerRate ?? widget.defaultRatePerKgUgx;

  /// A typed override, rounded, or null when the field is blank or unusable.
  double? get _typedRate {
    final parsed =
        double.tryParse(_customRateController.text.trim())?.roundToDouble();
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  /// Whether the typed rate actually differs from what would otherwise apply.
  /// Typing the same number as the default is not an override and must not
  /// demand a reason.
  bool get _isOverride {
    final typed = _typedRate;
    return typed != null && typed != _baseRate;
  }
```

- [ ] **Step 5: Validate on submit**

In `_onSubmit`, immediately after the existing custom-rate parse/guard block that ends at line 461, insert:

```dart
    final reason = _rateReasonController.text.trim();
    if (_isOverride) {
      if (reason.isEmpty) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Say why this order is priced differently.'),
        ));
        return;
      }
      final floor = rateFloorUgx(
        defaultRateUgx: widget.defaultRatePerKgUgx,
        minRatePct: widget.minRatePctOfDefault,
      );
      if (!isRateAllowed(
          rateUgx: customRate!, floorUgx: floor, isManager: widget.isManager)) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'That is below the minimum of ${formatUgx(floor)}/kg. A manager can approve it.'),
        ));
        return;
      }
    }
```

`customRate!` is safe here: `_isOverride` is only true when `_typedRate` is non-null, and `customRate` is parsed from the same field by the same rounding rule.

- [ ] **Step 6: Populate the audit fields on the order**

In the `LaundryOrder(...)` construction, after `ratePerKgSnapshotUgx: customRate ?? _resolvedRate,` (line 503):

```dart
      // Null on an ordinary order — an override is the exception, and a null
      // pair is what says "this was priced normally".
      rateOverrideReason: _isOverride ? reason : null,
      rateOverrideFromUgx: _isOverride ? _baseRate : null,
```

- [ ] **Step 7: Render the reason field**

Directly below the existing custom-rate `_Field` at line 900, inside the same optional-details section:

```dart
              if (_isOverride) ...[
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const Key('np_rate_reason'),
                  controller: _rateReasonController,
                  decoration: InputDecoration(
                    labelText: 'Why this rate?',
                    helperText:
                        'Replaces ${formatUgx(_baseRate.round())}/kg. Recorded on the order.',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
```

The custom-rate field needs `onChanged: (_) => setState(() {})` so `_isOverride` re-evaluates and this field appears as the rider types. Check whether it already has one before adding a second.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd apps/amuwak_staff && flutter test test/orders/new_pickup_custom_rate_test.dart`

Expected: PASS — ten tests (five pre-existing, five new).

Then: `flutter test test/orders/new_pickup_rate_test.dart` and `flutter test test/orders/new_pickup_screen_test.dart`

Expected: PASS. Both defaults are permissive, so no existing behaviour changed.

- [ ] **Step 9: Wire the real values at the call site**

`NewPickupScreen` is constructed at `staff_dashboard_screen.dart:243`, where a local `settings` already supplies the default rate. Add immediately after that line:

```dart
            minRatePctOfDefault: settings.minRatePctOfDefault,
            isManager: ref.read(currentRoleProvider) == 'manager',
```

- [ ] **Step 10: Run the full staff suite and check coverage**

Run: `cd apps/amuwak_staff && flutter test` (if it hangs on `loading`, run the changed directories one file at a time)

Then: `bash coverage/summary.sh`

Expected: all green, coverage at or above 98%.

- [ ] **Step 11: Commit**

```bash
git add apps/amuwak_staff/lib/src/orders/new_pickup_screen.dart apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart apps/amuwak_staff/test/orders/new_pickup_custom_rate_test.dart
git commit -F "$env:TEMP\msg.txt" -- apps/amuwak_staff/lib/src/orders/new_pickup_screen.dart apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart apps/amuwak_staff/test/orders/new_pickup_custom_rate_test.dart
```

Message: `feat(orders): require a reason for a rate override and bound it by a floor`

---

## Follow-up outside this plan

- **Update spec Part 6 item 2** to say the audit is two columns on `orders`, not a `rate_override_audit` table, with the offline-first reasoning above.
- **Surface `min_rate_pct_of_default` in the pricing settings screen** (`apps/amuwak_staff/lib/src/pricing/pricing_settings_screen.dart`). Until then the floor can only be set with SQL, which is acceptable for a first cut — 0 means disabled and nothing regresses — but it is the obvious next increment.
- **Show the override on the order detail screen** so a manager reviewing an order sees the reason without querying the database.
