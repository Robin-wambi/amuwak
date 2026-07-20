-- 0051_carts.sql
-- Server copy of a customer's in-progress cart (one row per customer) so the
-- cart follows them across devices. The device keeps a local Drift copy as the
-- working source of truth and mirrors here when online; `updated_at` is set by
-- the client so last-write-wins reconciliation is under the client's control
-- (no trigger). `items` is a jsonb array of cart lines (same shape as
-- orders.cart_items). Not in the realtime publication — the client reconciles
-- on load, it does not need a live stream.
--
-- RLS: a customer reads/writes ONLY their own cart, via auth_customer_id().
-- Table privileges come from Supabase's default grant to `authenticated`; RLS
-- narrows them to the owner.

CREATE TABLE carts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL UNIQUE REFERENCES customers(id) ON DELETE CASCADE,
  items       jsonb NOT NULL DEFAULT '[]'::jsonb
              CHECK (jsonb_typeof(items) = 'array'),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE carts ENABLE ROW LEVEL SECURITY;

CREATE POLICY carts_customer_read ON carts FOR SELECT
  USING (customer_id = auth_customer_id());

CREATE POLICY carts_customer_insert ON carts FOR INSERT
  WITH CHECK (customer_id = auth_customer_id());

CREATE POLICY carts_customer_update ON carts FOR UPDATE
  USING (customer_id = auth_customer_id())
  WITH CHECK (customer_id = auth_customer_id());

CREATE POLICY carts_customer_delete ON carts FOR DELETE
  USING (customer_id = auth_customer_id());
