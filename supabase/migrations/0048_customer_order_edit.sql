-- 0048_customer_order_edit.sql
-- Let a customer amend or cancel their OWN order — but only while it is still
-- pending_pickup (before a rider has collected it), and only the descriptive
-- fields. Never price, status, fulfilment method, or attribution.
--
-- Done as two SECURITY DEFINER RPCs rather than a customer UPDATE policy on
-- orders: a row-level UPDATE policy cannot restrict WHICH COLUMNS change (the
-- same lesson as order_messages in 0046), so a broad grant would let a customer
-- rewrite their own total or advance their status. These functions validate
-- ownership + editability and touch only the allowed columns. staff attribution
-- columns are pinned to the system sentinel (…a001), matching how the order was
-- created (0044/0046).

-- Amend the descriptive details of a pending order. Excludes fulfilment_method
-- on purpose: switching delivery<->collect changes the delivery fee (price), and
-- customers never edit price. Excludes weight/pricing entirely. item_count keeps
-- the orders_item_count_check (> 0) invariant with an explicit guard so the
-- caller gets a clear error rather than a raw constraint violation.
CREATE FUNCTION customer_update_order_details(
  p_order_id     uuid,
  p_service_type text,
  p_address      text,
  p_item_count   int,
  p_notes        text,
  p_scheduled_for timestamptz
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_cust uuid := auth_customer_id();
BEGIN
  IF v_cust IS NULL THEN
    RAISE EXCEPTION 'customer_update_order_details requires a linked customer';
  END IF;
  IF p_item_count < 1 THEN
    RAISE EXCEPTION 'item_count must be at least 1';
  END IF;

  UPDATE orders
     SET service_type  = p_service_type,
         address       = p_address,
         item_count    = p_item_count,
         notes         = COALESCE(p_notes, ''),
         scheduled_for = p_scheduled_for,
         updated_by    = '00000000-0000-0000-0000-00000000a001',
         updated_at    = now()
   WHERE id          = p_order_id
     AND customer_id = v_cust
     AND status      = 'pending_pickup'
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'order % is not yours, does not exist, or is no longer editable', p_order_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION
  customer_update_order_details(uuid, text, text, int, text, timestamptz)
  FROM public, anon;
GRANT EXECUTE ON FUNCTION
  customer_update_order_details(uuid, text, text, int, text, timestamptz)
  TO authenticated;

-- Cancel (soft-delete) a pending order. A cancelled order drops off both the
-- customer's and staff's active lists (both filter deleted_at IS NULL), exactly
-- like a staff back-office tombstone; deleted_by is the sentinel so the audit
-- trail shows it came through the customer app.
CREATE FUNCTION customer_cancel_order(p_order_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_cust uuid := auth_customer_id();
BEGIN
  IF v_cust IS NULL THEN
    RAISE EXCEPTION 'customer_cancel_order requires a linked customer';
  END IF;

  UPDATE orders
     SET deleted_at = now(),
         deleted_by = '00000000-0000-0000-0000-00000000a001',
         updated_at = now()
   WHERE id          = p_order_id
     AND customer_id = v_cust
     AND status      = 'pending_pickup'
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'order % is not yours, does not exist, or can no longer be cancelled', p_order_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION customer_cancel_order(uuid) FROM public, anon;
GRANT  EXECUTE ON FUNCTION customer_cancel_order(uuid) TO authenticated;
