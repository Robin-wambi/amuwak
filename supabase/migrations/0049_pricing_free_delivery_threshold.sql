-- 0049_pricing_free_delivery_threshold.sql
-- Free-delivery threshold: delivery is waived on an order whose pre-delivery
-- subtotal (weight charge + line items + express) reaches this amount. 0 (the
-- default) disables the feature. Additive; the existing singleton row degrades
-- to 0. Customers already read pricing_settings (pricing_settings_customer_read,
-- migration 0046), so no new grant is needed to expose it to the cart estimate.

ALTER TABLE pricing_settings
  ADD COLUMN free_delivery_threshold_ugx integer NOT NULL DEFAULT 0
  CHECK (free_delivery_threshold_ugx >= 0);
