-- 0050_orders_cart_items_test.sql
BEGIN;
SET search_path TO extensions, public;

SELECT plan(3);

SELECT has_column('orders', 'cart_items', 'orders.cart_items exists');

INSERT INTO public.staff (id, username, display_name, role, active) VALUES
  ('00000000-0000-0000-0000-00000000a001', 'system_customer_app',
   'Customer App', 'in_shop', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customers (id, name, phone) VALUES
  ('00000000-0000-0000-0000-00000000c201', 'C201', '0700000201');

INSERT INTO public.orders (
  id, order_code, customer_id, placed_by_customer_id, customer_name, phone,
  address, service_type, status, intake_method, fulfillment_method, item_count,
  intake_recorded_by, created_by
) VALUES (
  '00000000-0000-0000-0000-00000000b201', 'AMW-CART-1',
  '00000000-0000-0000-0000-00000000c201', '00000000-0000-0000-0000-00000000c201',
  'C201', '0700000201', 'Addr', 'wash_fold', 'pending_pickup',
  'customer_app', 'delivery', 3,
  '00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a001');

SELECT is(
  (SELECT cart_items FROM orders
    WHERE id = '00000000-0000-0000-0000-00000000b201'),
  '[]'::jsonb, 'cart_items defaults to an empty array');

PREPARE bad_cart AS
  UPDATE orders SET cart_items = '{}'::jsonb
   WHERE id = '00000000-0000-0000-0000-00000000b201';
SELECT throws_ok('bad_cart', '23514', NULL,
  'a non-array cart_items is rejected');

SELECT * FROM finish();
ROLLBACK;
