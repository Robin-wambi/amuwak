-- 0059_rate_override_audit.sql
-- Makes a per-order rate override accountable, and bounds how low one can go.
--
-- Until now any rider could type any rate into New Pickup and the order simply
-- billed at it, with nothing recorded about what it replaced or why. Two
-- columns on `orders` close that: the rate that would otherwise have applied,
-- and a free-text reason.
--
-- The audit lives on `orders` rather than in its own table on purpose. New
-- Pickup is offline-first: the order is written to a local Drift DB and the
-- create_pickup RPC is queued on the outbox. A separate audit table would need
-- its own outbox op and could drain independently of the order it describes.
-- Columns on the audited row cannot desynchronise from it.
--
-- `min_rate_pct_of_default` is the floor, as a whole percentage of the global
-- default rate. 0 disables it, which is the default so this migration changes
-- no existing behaviour until a manager sets a value.
--
-- The floor is enforced inside create_pickup rather than as a CHECK constraint:
-- it compares against a value in another table, and managers are exempt.
-- create_pickup is already the only path a rider has into `orders`.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS rate_override_reason   text,
  ADD COLUMN IF NOT EXISTS rate_override_from_ugx numeric;

ALTER TABLE pricing_settings
  ADD COLUMN IF NOT EXISTS min_rate_pct_of_default integer NOT NULL DEFAULT 0
    CHECK (min_rate_pct_of_default >= 0 AND min_rate_pct_of_default <= 100);

-- CREATE OR REPLACE keeps the existing EXECUTE grants (authenticated), so they
-- are not re-issued. Verbatim copy of the 0058 body with:
--   1. the two audit columns threaded through the explicit INSERT column list
--      (the function does not pass p_order through generically, so a new column
--      is silently dropped on create until it is named here), and
--   2. the floor check added before the INSERT.
CREATE OR REPLACE FUNCTION create_pickup(p_customer jsonb, p_order jsonb)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_caller      uuid := auth.uid();
  v_role        text := auth_staff_role();
  v_customer_id uuid := (p_customer->>'id')::uuid;
  v_order_id    uuid := (p_order->>'id')::uuid;
  v_code        text;
  v_assigned    uuid;
  v_rate        numeric := COALESCE((p_order->>'rate_per_kg_snapshot_ugx')::numeric, 0);
  v_floor       numeric;
BEGIN
  IF v_caller IS NULL OR v_role IS NULL THEN
    RAISE EXCEPTION 'create_pickup requires an active staff caller';
  END IF;
  IF v_customer_id IS NULL OR v_order_id IS NULL THEN
    RAISE EXCEPTION 'create_pickup requires customer id and order id';
  END IF;

  -- Rate floor. Managers are exempt; 0 or no settings row disables it. Checked
  -- for a zero rate too: nothing about billing at 0 makes it exempt from the
  -- floor, and this RPC is reachable by any authenticated staff caller, not
  -- only through the app (which never sends 0 today).
  IF v_role <> 'manager' THEN
    SELECT default_rate_per_kg_ugx * min_rate_pct_of_default / 100.0
      INTO v_floor FROM pricing_settings LIMIT 1;
    IF v_floor IS NOT NULL AND v_floor > 0 AND v_rate < v_floor THEN
      RAISE EXCEPTION 'rate_below_floor'
        USING DETAIL = format('rate %s is below the floor of %s', v_rate, v_floor);
    END IF;
  END IF;

  -- Upsert the customer (bypasses customers_write via SECURITY DEFINER; only
  -- reachable after the staff check above). Intentional shared-CRM behaviour:
  -- passing an existing customer id overwrites the stored
  -- name/phone/address/notes/custom_rate_per_kg_ugx.
  INSERT INTO customers (
    id, name, phone, address, notes, custom_rate_per_kg_ugx, created_at, updated_at
  ) VALUES (
    v_customer_id,
    p_customer->>'name',
    p_customer->>'phone',
    p_customer->>'address',
    p_customer->>'notes',
    (p_customer->>'custom_rate_per_kg_ugx')::numeric,
    COALESCE((p_customer->>'created_at')::timestamptz, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    name                   = EXCLUDED.name,
    phone                  = EXCLUDED.phone,
    address                = EXCLUDED.address,
    notes                  = EXCLUDED.notes,
    custom_rate_per_kg_ugx = EXCLUDED.custom_rate_per_kg_ugx,
    updated_at             = now();

  -- Idempotent order create: a retry with the same id returns the existing code.
  SELECT o.order_code INTO v_code FROM orders o WHERE o.id = v_order_id;
  IF v_code IS NOT NULL THEN
    RETURN jsonb_build_object('order_id', v_order_id, 'order_code', v_code);
  END IF;

  v_code     := next_order_code();
  v_assigned := CASE WHEN v_role = 'driver' THEN v_caller ELSE NULL END;

  INSERT INTO orders (
    id, order_code, customer_id, customer_name, phone, address,
    service_type, status, intake_method, fulfillment_method, item_count, notes,
    scheduled_for, expected_collection_at,
    rate_override_reason, rate_override_from_ugx,
    rate_per_kg_snapshot_ugx, estimated_weight_kg, final_weight_kg,
    line_items, manual_adjustment_ugx, delivery_fee_snapshot_ugx, is_express,
    express_flat_snapshot_ugx, express_pct_snapshot, total_ugx,
    assigned_driver, intake_recorded_by, created_by, created_at, updated_at
  ) VALUES (
    v_order_id, v_code, v_customer_id,
    p_order->>'customer_name', p_order->>'phone', p_order->>'address',
    p_order->>'service_type', 'pending_pickup',
    COALESCE(p_order->>'intake_method', 'driver_pickup'),
    COALESCE(p_order->>'fulfillment_method', 'delivery'),
    (p_order->>'item_count')::int, COALESCE(p_order->>'notes', ''),
    (p_order->>'scheduled_for')::timestamptz,
    (p_order->>'expected_collection_at')::timestamptz,
    p_order->>'rate_override_reason',
    (p_order->>'rate_override_from_ugx')::numeric,
    COALESCE((p_order->>'rate_per_kg_snapshot_ugx')::numeric, 0),
    (p_order->>'estimated_weight_kg')::numeric,
    (p_order->>'final_weight_kg')::numeric,
    COALESCE(p_order->'line_items', '[]'::jsonb),
    COALESCE((p_order->>'manual_adjustment_ugx')::int, 0),
    COALESCE((p_order->>'delivery_fee_snapshot_ugx')::int, 0),
    COALESCE((p_order->>'is_express')::boolean, false),
    COALESCE((p_order->>'express_flat_snapshot_ugx')::int, 0),
    COALESCE((p_order->>'express_pct_snapshot')::numeric, 0),
    COALESCE((p_order->>'total_ugx')::int, 0),
    v_assigned, v_caller, v_caller, now(), now()
  );

  RETURN jsonb_build_object('order_id', v_order_id, 'order_code', v_code);
END;
$$;
