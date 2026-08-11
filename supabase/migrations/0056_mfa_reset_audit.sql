-- 0056_mfa_reset_audit.sql
-- Clearing a staff member's TOTP factor deliberately weakens their account.
-- That must never be invisible: who did it, to whom, and how many factors went.
--
-- Insert-only from the server. The reset-staff-mfa Edge Function writes with
-- the service-role key, which bypasses RLS; no client-facing policy grants
-- INSERT, UPDATE or DELETE, so the log cannot be forged or erased from the app.

CREATE TABLE mfa_reset_audit (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_staff_id   uuid NOT NULL REFERENCES staff(id),
  target_staff_id  uuid NOT NULL REFERENCES staff(id),
  factors_cleared  int  NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX mfa_reset_audit_target_idx
  ON mfa_reset_audit (target_staff_id, created_at DESC);

ALTER TABLE mfa_reset_audit ENABLE ROW LEVEL SECURITY;

-- is_active_manager() (0055) rather than auth_staff_role(): the latter checks
-- `active` but not `deleted_at IS NULL`, so a soft-deleted manager would keep
-- read access to the security-audit log. Both exclude drivers.
CREATE POLICY mfa_reset_audit_manager_read ON mfa_reset_audit FOR SELECT
  USING (is_active_manager(auth.uid()));
