-- 0029_orders_audit_columns_test.sql
-- Verifies orders.updated_by / orders.deleted_by exist and use ON DELETE SET
-- NULL: deleting the staff member they point at clears the references instead
-- of raising a FK error. Runs inside BEGIN ... ROLLBACK so nothing touches real
-- data.

BEGIN;
SET search_path TO extensions, public;

SELECT plan(5);

SELECT has_column('public', 'orders', 'updated_by', 'orders.updated_by exists');
SELECT has_column('public', 'orders', 'deleted_by', 'orders.deleted_by exists');

-- Two staff: the creator backs the NOT NULL created_by/intake_recorded_by FKs
-- (which we must NOT delete), the auditor backs the new nullable audit columns
-- (which we delete to exercise ON DELETE SET NULL).
-- audit_actor's role is deliberately not 'manager': migration 0054 forbids
-- dropping below two active managers, and this row gets deleted below.
INSERT INTO public.staff (id, username, display_name, role) VALUES
  ('00000000-0000-0000-0000-000000002600', 'audit_creator', 'Audit Creator', 'in_shop'),
  ('00000000-0000-0000-0000-000000002601', 'audit_actor',   'Audit Actor',   'in_shop');

INSERT INTO public.customers (id, name, phone) VALUES
  ('00000000-0000-0000-0000-000000002602', 'Audit Test Customer', '+256700000026');

INSERT INTO public.orders (
  id, order_code, customer_id, customer_name, phone, address,
  service_type, status, intake_method, fulfillment_method, item_count,
  intake_recorded_by, created_by, updated_by, deleted_by
) VALUES (
  '00000000-0000-0000-0000-000000002603',
  'AMW-AUDIT-TEST-1', -- test sentinel; order_code has no format CHECK constraint
  '00000000-0000-0000-0000-000000002602',
  'Audit Test Customer', '+256700000026', 'Test Address',
  'wash_fold', 'received', 'walk_in', 'delivery', 1,
  '00000000-0000-0000-0000-000000002600',  -- intake_recorded_by (creator)
  '00000000-0000-0000-0000-000000002600',  -- created_by (creator)
  '00000000-0000-0000-0000-000000002601',  -- updated_by (auditor)
  '00000000-0000-0000-0000-000000002601'   -- deleted_by (auditor)
);

-- Deleting the auditor must NOT raise — NO ACTION/RESTRICT would.
SELECT lives_ok(
  $$DELETE FROM staff WHERE id = '00000000-0000-0000-0000-000000002601'$$,
  'deleting the staff referenced by updated_by/deleted_by does not raise');

-- Both references are nulled, not left dangling.
SELECT is(
  (SELECT updated_by FROM orders WHERE id = '00000000-0000-0000-0000-000000002603'),
  NULL::uuid,
  'orders.updated_by is SET NULL when the referenced staff is deleted');

SELECT is(
  (SELECT deleted_by FROM orders WHERE id = '00000000-0000-0000-0000-000000002603'),
  NULL::uuid,
  'orders.deleted_by is SET NULL when the referenced staff is deleted');

SELECT * FROM finish();
ROLLBACK;
