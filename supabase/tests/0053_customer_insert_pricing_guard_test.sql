-- 0053_customer_insert_pricing_guard_test.sql
-- The money columns a customer must not assert on their own order at insert,
-- and proof the legitimate checkout path still works.
BEGIN;
SET search_path TO extensions, public;

SELECT plan(6);

INSERT INTO public.customers (id, name, phone, auth_user_id) VALUES
  ('00000000-0000-0000-0000-00000000c301', 'Cust1', '0700000301',
   '00000000-0000-0000-0000-00000000a301');

INSERT INTO public.staff (id, username, display_name, role, active) VALUES
  ('00000000-0000-0000-0000-00000000a001', 'system_customer_app',
   'Customer App', 'in_shop', false)
ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a301';

-- The real checkout payload: a frozen provisional estimate, nothing collected,
-- not yet weighed. This is exactly what orderUpsertPayload sends.
PREPARE place_ok AS
  INSERT INTO orders (
    order_code, customer_id, placed_by_customer_id, customer_name, phone,
    address, service_type, status, intake_method, fulfillment_method, item_count,
    intake_recorded_by, created_by,
    total_ugx, rate_per_kg_snapshot_ugx, delivery_fee_snapshot_ugx,
    estimated_weight_kg, payment_amount_ugx, manual_adjustment_ugx,
    final_weight_kg
  ) VALUES (
    'AMW-GUARD-OK', '00000000-0000-0000-0000-00000000c301',
    '00000000-0000-0000-0000-00000000c301', 'Cust1', '0700000301', 'Addr',
    'wash_fold', 'pending_pickup', 'customer_app', 'delivery', 2,
    '00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a001',
    47500, 5000, 3000, 6.5, 0, 0, NULL);
SELECT lives_ok('place_ok',
  'a normal checkout (estimate frozen, nothing paid, unweighed) still inserts');

-- The attack: claim the order is already paid. Staff collection is gated on
-- outstanding = total - collected, so this would read as settled.
PREPARE forge_paid AS
  INSERT INTO orders (
    order_code, customer_id, placed_by_customer_id, customer_name, phone,
    address, service_type, status, intake_method, fulfillment_method, item_count,
    intake_recorded_by, created_by, total_ugx, payment_amount_ugx
  ) VALUES (
    'AMW-GUARD-PAID', '00000000-0000-0000-0000-00000000c301',
    '00000000-0000-0000-0000-00000000c301', 'Cust1', '0700000301', 'Addr',
    'wash_fold', 'pending_pickup', 'customer_app', 'delivery', 2,
    '00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a001',
    47500, 47500);
SELECT throws_ok('forge_paid', '42501', NULL,
  'a customer cannot insert an order that claims payment was collected');

-- The nastier variant: a huge collected amount survives staff re-pricing,
-- because outstanding clamps at 0.
PREPARE forge_credit AS
  INSERT INTO orders (
    order_code, customer_id, placed_by_customer_id, customer_name, phone,
    address, service_type, status, intake_method, fulfillment_method, item_count,
    intake_recorded_by, created_by, total_ugx, payment_amount_ugx
  ) VALUES (
    'AMW-GUARD-CREDIT', '00000000-0000-0000-0000-00000000c301',
    '00000000-0000-0000-0000-00000000c301', 'Cust1', '0700000301', 'Addr',
    'wash_fold', 'pending_pickup', 'customer_app', 'delivery', 2,
    '00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a001',
    0, 999999999);
SELECT throws_ok('forge_credit', '42501', NULL,
  'a customer cannot bank a credit that outlives staff re-pricing');

-- A customer-set final weight would also make the order look already weighed.
PREPARE forge_weight AS
  INSERT INTO orders (
    order_code, customer_id, placed_by_customer_id, customer_name, phone,
    address, service_type, status, intake_method, fulfillment_method, item_count,
    intake_recorded_by, created_by, final_weight_kg
  ) VALUES (
    'AMW-GUARD-WEIGHT', '00000000-0000-0000-0000-00000000c301',
    '00000000-0000-0000-0000-00000000c301', 'Cust1', '0700000301', 'Addr',
    'wash_fold', 'pending_pickup', 'customer_app', 'delivery', 2,
    '00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a001',
    0.1);
SELECT throws_ok('forge_weight', '42501', NULL,
  'a customer cannot declare the order already weighed');

PREPARE forge_adjustment AS
  INSERT INTO orders (
    order_code, customer_id, placed_by_customer_id, customer_name, phone,
    address, service_type, status, intake_method, fulfillment_method, item_count,
    intake_recorded_by, created_by, manual_adjustment_ugx
  ) VALUES (
    'AMW-GUARD-ADJ', '00000000-0000-0000-0000-00000000c301',
    '00000000-0000-0000-0000-00000000c301', 'Cust1', '0700000301', 'Addr',
    'wash_fold', 'pending_pickup', 'customer_app', 'delivery', 2,
    '00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a001',
    -40000);
SELECT throws_ok('forge_adjustment', '42501', NULL,
  'a customer cannot discount their own order');

-- Nothing forged made it in; only the legitimate order exists.
RESET ROLE;
SELECT is(
  (SELECT count(*)::int FROM orders WHERE order_code LIKE 'AMW-GUARD-%'),
  1, 'only the legitimate checkout row was written');

SELECT * FROM finish();
ROLLBACK;
