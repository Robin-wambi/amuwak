-- 0049_pricing_free_delivery_threshold_test.sql
BEGIN;
SET search_path TO extensions, public;

SELECT plan(2);

SELECT has_column('pricing_settings', 'free_delivery_threshold_ugx',
  'pricing_settings.free_delivery_threshold_ugx exists');

-- The CHECK forbids a negative threshold (0019 seeds the singleton row).
PREPARE bad_threshold AS
  UPDATE pricing_settings SET free_delivery_threshold_ugx = -1;
SELECT throws_ok('bad_threshold', '23514', NULL,
  'a negative free-delivery threshold is rejected');

SELECT * FROM finish();
ROLLBACK;
