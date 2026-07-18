-- 0048_customer_order_edit_test.sql
BEGIN;
SET search_path TO extensions, public;

SELECT plan(9);

-- Two customers, each linked to an auth user.
INSERT INTO public.customers (id, name, phone, auth_user_id) VALUES
  ('00000000-0000-0000-0000-00000000c101', 'Cust1', '0700000101',
   '00000000-0000-0000-0000-00000000a101'),
  ('00000000-0000-0000-0000-00000000c102', 'Cust2', '0700000102',
   '00000000-0000-0000-0000-00000000a102');

-- A pending order + an in-progress order, both Cust1's (sentinel attribution).
INSERT INTO public.orders (
  id, order_code, customer_id, placed_by_customer_id, customer_name, phone,
  address, service_type, status, intake_method, fulfillment_method, item_count,
  intake_recorded_by, created_by
) VALUES
  ('00000000-0000-0000-0000-0000000000d1', 'AMW-EDIT-1',
   '00000000-0000-0000-0000-00000000c101', '00000000-0000-0000-0000-00000000c101',
   'Cust1', '0700000101', 'Old Addr', 'Wash & Iron', 'pending_pickup',
   'customer_app', 'delivery', 3,
   '00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000000d2', 'AMW-EDIT-2',
   '00000000-0000-0000-0000-00000000c101', '00000000-0000-0000-0000-00000000c101',
   'Cust1', '0700000101', 'Addr2', 'Wash & Iron', 'in_progress',
   'customer_app', 'delivery', 2,
   '00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a001');

-- ---- Cust1 edits their own pending order ----
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a101';

SELECT lives_ok(
  $$SELECT customer_update_order_details(
      '00000000-0000-0000-0000-0000000000d1', 'Dry cleaning', 'New Addr', 5,
      'leave at gate', NULL)$$,
  'Cust1 can edit their own pending order');

SELECT is((SELECT address FROM orders WHERE id = '00000000-0000-0000-0000-0000000000d1'),
          'New Addr', 'address updated');
SELECT is((SELECT item_count FROM orders WHERE id = '00000000-0000-0000-0000-0000000000d1'),
          5, 'item_count updated');

-- item_count < 1 rejected (guards the orders_item_count_check invariant).
SELECT throws_ok(
  $$SELECT customer_update_order_details(
      '00000000-0000-0000-0000-0000000000d1', 'Wash & Iron', 'A', 0, '', NULL)$$,
  NULL, NULL, 'item_count < 1 rejected');

-- Cannot edit a no-longer-pending order.
SELECT throws_ok(
  $$SELECT customer_update_order_details(
      '00000000-0000-0000-0000-0000000000d2', 'Wash & Iron', 'A', 1, '', NULL)$$,
  NULL, NULL, 'cannot edit an in_progress order');

-- ---- Cust2 cannot touch Cust1's order ----
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a102';

SELECT throws_ok(
  $$SELECT customer_update_order_details(
      '00000000-0000-0000-0000-0000000000d1', 'Wash & Iron', 'HACK', 1, '', NULL)$$,
  NULL, NULL, 'Cust2 cannot edit Cust1 order');

SELECT throws_ok(
  $$SELECT customer_cancel_order('00000000-0000-0000-0000-0000000000d1')$$,
  NULL, NULL, 'Cust2 cannot cancel Cust1 order');

-- ---- Cust1 cancels their own pending order ----
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a101';

SELECT lives_ok(
  $$SELECT customer_cancel_order('00000000-0000-0000-0000-0000000000d1')$$,
  'Cust1 can cancel their own pending order');

SELECT isnt(
  (SELECT deleted_at FROM orders WHERE id = '00000000-0000-0000-0000-0000000000d1'),
  NULL, 'cancelled order is soft-deleted');

SELECT * FROM finish();
ROLLBACK;
