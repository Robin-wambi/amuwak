-- 0058_orders_expected_collection.sql
-- Adds orders.expected_collection_at: the date staff promised the order would be
-- ready for collection/delivery (distinct from scheduled_for, the pickup time).
--
-- Two parts:
--   1. ADD the nullable column (existing rows backfill as NULL).
--   2. CREATE OR REPLACE create_pickup() so a New Pickup can set it at creation.
--      The RPC has an explicit INSERT column list (it does not pass p_order
--      through generically), so a new column is silently dropped on create until
--      it's added here. This is a verbatim copy of the 0040 body with the one
--      column threaded through; nothing else changes. CREATE OR REPLACE keeps
--      the existing EXECUTE grants (authenticated), so they aren't re-issued.
--
-- Post-creation edits set the column via a plain UPDATE (orderDetailsUpdatePayload
-- under the orders_update RLS), so no other function needs touching.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS expected_collection_at timestamptz;

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
BEGIN
  IF v_caller IS NULL OR v_role IS NULL THEN
    RAISE EXCEPTION 'create_pickup requires an active staff caller';
  END IF;
  IF v_customer_id IS NULL OR v_order_id IS NULL THEN
    RAISE EXCEPTION 'create_pickup requires customer id and order id';
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
