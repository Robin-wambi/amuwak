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
