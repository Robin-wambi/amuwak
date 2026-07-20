-- 0051_carts_test.sql
BEGIN;
SET search_path TO extensions, public;

SELECT plan(5);

INSERT INTO public.customers (id, name, phone, auth_user_id) VALUES
  ('00000000-0000-0000-0000-00000000c201', 'C201', '0700000201',
   '00000000-0000-0000-0000-00000000a201'),
  ('00000000-0000-0000-0000-00000000c202', 'C202', '0700000202',
   '00000000-0000-0000-0000-00000000a202');

-- ---- Cust1 owns their cart ----
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a201';

PREPARE ins_ok AS
  INSERT INTO carts (customer_id, items)
  VALUES ('00000000-0000-0000-0000-00000000c201', '[]'::jsonb);
SELECT lives_ok('ins_ok', 'Cust1 creates their own cart');

SELECT is((SELECT count(*)::int FROM carts
           WHERE customer_id = '00000000-0000-0000-0000-00000000c201'),
          1, 'Cust1 sees their own cart');

PREPARE ins_forge AS
  INSERT INTO carts (customer_id, items)
  VALUES ('00000000-0000-0000-0000-00000000c202', '[]'::jsonb);
SELECT throws_ok('ins_forge', '42501', NULL,
  'Cust1 cannot create a cart for Cust2');

-- ---- Cust2 is denied Cust1's cart ----
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a202';

SELECT is((SELECT count(*)::int FROM carts
           WHERE customer_id = '00000000-0000-0000-0000-00000000c201'),
          0, 'Cust2 cannot see Cust1 cart');

-- No update policy match for Cust2 → a silent no-op, not a raise.
UPDATE carts SET items = '[{"x":1}]'::jsonb
 WHERE customer_id = '00000000-0000-0000-0000-00000000c201';
RESET ROLE;
SELECT is((SELECT items FROM carts
           WHERE customer_id = '00000000-0000-0000-0000-00000000c201'),
          '[]'::jsonb, "Cust2's update of Cust1 cart is a no-op");

SELECT * FROM finish();
ROLLBACK;
