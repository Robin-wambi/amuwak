-- 0020_pricing_settings_updated_by_on_delete_test.sql
-- Verifies pricing_settings.updated_by uses ON DELETE SET NULL: deleting the
-- staff member it points at clears the reference instead of raising a FK error.
-- Runs inside BEGIN ... ROLLBACK so nothing touches real data.

BEGIN;
SET search_path TO extensions, public;

SELECT plan(2);

-- Seed a throwaway staff member and point the singleton settings row at them.
-- Role is deliberately not 'manager': migration 0054 forbids dropping below
-- two active managers, and this row gets deleted below.
INSERT INTO public.staff (id, username, display_name, role) VALUES
  ('00000000-0000-0000-0000-000000002000', 'pricing_fk_mgr', 'Pricing FK Mgr', 'in_shop');

UPDATE pricing_settings
  SET updated_by = '00000000-0000-0000-0000-000000002000';

-- Deleting that staff member must NOT raise — NO ACTION/RESTRICT would.
SELECT lives_ok(
  $$DELETE FROM staff WHERE id = '00000000-0000-0000-0000-000000002000'$$,
  'deleting the staff who last updated pricing_settings does not raise');

-- The reference is nulled, not left dangling.
SELECT is(
  (SELECT updated_by FROM pricing_settings),
  NULL::uuid,
  'pricing_settings.updated_by is SET NULL when the referenced staff is deleted');

SELECT * FROM finish();
ROLLBACK;
