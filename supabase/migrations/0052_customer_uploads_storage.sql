-- 0052_customer_uploads_storage.sql
-- Private bucket for customer-supplied photos (e.g. a damaged/stained item on a
-- cart line). Unlike the shared proof-photos bucket (0008), access is scoped to
-- the owning customer: objects live under customer/<auth_customer_id>/..., and a
-- customer may read/write ONLY their own prefix. Staff (any active role) may read
-- the whole bucket so they can view damage photos on orders they handle. No
-- UPDATE/DELETE policy — customer uploads are immutable from the client.

INSERT INTO storage.buckets (id, name, public)
VALUES ('customer-uploads', 'customer-uploads', false)
ON CONFLICT (id) DO NOTHING;

-- A customer reads only objects under their own customer/<id>/ prefix.
CREATE POLICY customer_uploads_owner_read ON storage.objects FOR SELECT
  USING (
    bucket_id = 'customer-uploads'
    AND (storage.foldername(name))[1] = 'customer'
    AND (storage.foldername(name))[2] = auth_customer_id()::text
  );

-- Staff may read any customer upload (to see damage photos at intake).
CREATE POLICY customer_uploads_staff_read ON storage.objects FOR SELECT
  USING (
    bucket_id = 'customer-uploads'
    AND auth_staff_role() IN ('driver','in_shop','manager')
  );

-- A customer writes only under their own prefix.
CREATE POLICY customer_uploads_owner_write ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'customer-uploads'
    AND (storage.foldername(name))[1] = 'customer'
    AND (storage.foldername(name))[2] = auth_customer_id()::text
  );
