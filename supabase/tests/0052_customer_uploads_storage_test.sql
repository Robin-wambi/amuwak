-- 0052_customer_uploads_storage_test.sql
BEGIN;
SET search_path TO extensions, public;

SELECT plan(4);

INSERT INTO public.customers (id, name, phone, auth_user_id) VALUES
  ('00000000-0000-0000-0000-00000000c201', 'C201', '0700000201',
   '00000000-0000-0000-0000-00000000a201'),
  ('00000000-0000-0000-0000-00000000c202', 'C202', '0700000202',
   '00000000-0000-0000-0000-00000000a202');

-- A staff member whose id equals their auth uid (auth_staff_role() looks up by id).
INSERT INTO public.staff (id, username, display_name, role, active) VALUES
  ('00000000-0000-0000-0000-00000000a901', 'staffq', 'Staff Q', 'in_shop', true);

-- ---- Cust1 writes only under their own prefix ----
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a201';

PREPARE write_own AS
  INSERT INTO storage.objects (bucket_id, name)
  VALUES ('customer-uploads',
          'customer/00000000-0000-0000-0000-00000000c201/cart/x.jpg');
SELECT lives_ok('write_own', 'Cust1 writes under their own prefix');

PREPARE write_forge AS
  INSERT INTO storage.objects (bucket_id, name)
  VALUES ('customer-uploads',
          'customer/00000000-0000-0000-0000-00000000c202/cart/y.jpg');
SELECT throws_ok('write_forge', '42501', NULL,
  'Cust1 cannot write under Cust2 prefix');

-- ---- Cust2 cannot read Cust1's object ----
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a202';
SELECT is((SELECT count(*)::int FROM storage.objects
           WHERE name = 'customer/00000000-0000-0000-0000-00000000c201/cart/x.jpg'),
          0, 'Cust2 cannot read Cust1 upload');

-- ---- Staff may read any customer upload ----
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claim.sub" = '00000000-0000-0000-0000-00000000a901';
SELECT is((SELECT count(*)::int FROM storage.objects
           WHERE name = 'customer/00000000-0000-0000-0000-00000000c201/cart/x.jpg'),
          1, 'staff can read a customer upload');

SELECT * FROM finish();
ROLLBACK;
