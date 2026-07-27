-- 0053_customer_insert_pricing_guard.sql
-- Closes a hole in `orders_customer_insert` (0046): the policy pinned
-- attribution, status and intake columns, but left the money columns free. RLS
-- — not the Flutter app — is the security boundary here: anything a valid
-- customer JWT can POST to /rest/v1/orders is reachable, whatever the app
-- happens to send.
--
-- The dangerous one is `payment_amount_ugx`. Staff collection is gated on
-- `outstanding = total - collected` (clamped at 0), so an order inserted with a
-- large payment already recorded reads as fully paid, disables the staff
-- "Record payment" action, and — because of the clamp — STAYS that way even
-- after staff weigh the load and set the real total. The laundry goes back
-- without cash being taken, and the forged amount inflates the collected figure
-- on the daily report.
--
-- `final_weight_kg` and `manual_adjustment_ugx` are pinned for the same reason:
-- both feed the priced total, and a customer-set final weight would also make
-- the order look already weighed (`isProvisional` is derived from it being
-- null).
--
-- `total_ugx` and the rate/delivery/express snapshots stay customer-writable ON
-- INSERT by design: a customer-app order legitimately freezes its provisional
-- estimate at checkout, and staff re-price it on weighing. With
-- `payment_amount_ugx` pinned to 0 a forged total can never read as paid
-- (`isFullyPaid` needs collected >= total), so it is worth no more than a
-- misleading estimate that staff overwrite anyway.
--
-- Only the WITH CHECK is replaced; the customer app already sends 0 / 0 / NULL
-- for these three, so the legitimate checkout path is unaffected. There is
-- still no customer UPDATE policy, so this remains the only way in.

ALTER POLICY orders_customer_insert ON orders WITH CHECK (
  auth_customer_id() IS NOT NULL
  AND customer_id           = auth_customer_id()
  AND placed_by_customer_id = auth_customer_id()
  AND intake_method         = 'customer_app'
  AND status                = 'pending_pickup'
  AND fulfillment_method IN ('delivery','customer_collect')
  AND created_by            = '00000000-0000-0000-0000-00000000a001'
  AND intake_recorded_by    = '00000000-0000-0000-0000-00000000a001'
  -- Money a customer must never assert about their own order.
  AND payment_amount_ugx    = 0
  AND manual_adjustment_ugx = 0
  AND final_weight_kg IS NULL
);
