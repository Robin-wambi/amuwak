-- 0050_orders_cart_items.sql
-- Itemized snapshot of the cart a customer_app order was built from, so staff
-- see every requested item (service, weight/qty, note, photo key) even though
-- the order is still priced as one weighed pickup. Additive jsonb array; empty
-- for orders not placed via the cart. The customer sets it on insert (the
-- existing orders_customer_insert policy gates the whole row); staff render it
-- read-only. No new RLS: this is just another column on orders.

ALTER TABLE orders
  ADD COLUMN cart_items jsonb NOT NULL DEFAULT '[]'::jsonb
  CHECK (jsonb_typeof(cart_items) = 'array');
