-- 0059_rate_override_audit_test.sql
-- The two order audit columns and the pricing floor exist, and create_pickup
-- refuses a sub-floor rate from a driver while allowing it from a manager.
--
-- The floor is enforced inside create_pickup rather than by a CHECK, because it
-- compares against a value in another table and exempts managers — so it is
-- exercised through the RPC, with the driver/manager impersonation pattern from
-- 0040_create_pickup_rpc_test.sql, not asserted structurally.

BEGIN;
SET search_path TO extensions, public;

SELECT plan(10);

-- ---- Structure ----

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

-- ---- Behaviour ----

-- Precondition, asserted rather than assumed: the settings singleton the floor
-- is read from exists (seeded by 0019).
SELECT is((SELECT count(*)::int FROM pricing_settings), 1,
  'pricing_settings holds exactly one (singleton) row to read the floor from');

-- A known default and floor: 60% of 5,000 = 3,000.
UPDATE pricing_settings
   SET default_rate_per_kg_ugx = 5000,
       min_rate_pct_of_default = 60;

INSERT INTO public.staff (id, username, display_name, role) VALUES
  ('00000000-0000-0000-0000-000000005901', 'drv_floor', 'D Floor', 'driver'),
  ('00000000-0000-0000-0000-000000005902', 'mgr_floor', 'M Floor', 'manager');

-- ---- Act as the driver ----
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000005901';

-- A rate under the floor is refused for a non-manager.
SELECT throws_like($$
  SELECT create_pickup(
    '{"id":"00000000-0000-0000-0000-0000000059c1","name":"Low","phone":"+256700590001"}'::jsonb,
    '{"id":"00000000-0000-0000-0000-0000000059a1","customer_name":"Low","phone":"+256700590001","address":"Kikoni","service_type":"wash_fold","item_count":3,"rate_per_kg_snapshot_ugx":2000}'::jsonb
  )
$$, '%rate_below_floor%', 'a driver cannot create a pickup priced below the floor');

-- A rate at the floor is allowed, and the audit columns round-trip through the
-- RPC's explicit INSERT column list (the failure mode 0058 documents: a column
-- not named there is silently dropped on create).
SELECT lives_ok($$
  SELECT create_pickup(
    '{"id":"00000000-0000-0000-0000-0000000059c2","name":"Ok","phone":"+256700590002"}'::jsonb,
    '{"id":"00000000-0000-0000-0000-0000000059a2","customer_name":"Ok","phone":"+256700590002","address":"Kikoni","service_type":"wash_fold","item_count":3,"rate_per_kg_snapshot_ugx":3000,"rate_override_reason":"Bulk hostel deal","rate_override_from_ugx":5000}'::jsonb
  )
$$, 'a driver may price at the floor');

SELECT is(
  (SELECT rate_override_reason || ' @ ' || rate_override_from_ugx::text
     FROM orders WHERE id = '00000000-0000-0000-0000-0000000059a2'),
  'Bulk hostel deal @ 5000',
  'the reason and the replaced rate are persisted by create_pickup');

-- ---- Act as the manager ----
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000005902';

SELECT lives_ok($$
  SELECT create_pickup(
    '{"id":"00000000-0000-0000-0000-0000000059c3","name":"Mgr","phone":"+256700590003"}'::jsonb,
    '{"id":"00000000-0000-0000-0000-0000000059a3","customer_name":"Mgr","phone":"+256700590003","address":"Ntinda","service_type":"wash_fold","item_count":1,"rate_per_kg_snapshot_ugx":2000,"rate_override_reason":"Manager approved","rate_override_from_ugx":5000}'::jsonb
  )
$$, 'a manager is exempt from the floor');

SELECT * FROM finish();
ROLLBACK;
