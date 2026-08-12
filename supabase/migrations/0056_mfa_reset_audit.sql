-- 0056_mfa_reset_audit.sql
-- Clearing a staff member's TOTP factor deliberately weakens their account.
-- That must never be invisible: who did it, to whom, and how many factors went.
--
-- Insert-only from the server. The reset-staff-mfa Edge Function writes with
-- the service-role key, which bypasses RLS. Clients are held off twice over:
-- no policy grants INSERT, UPDATE or DELETE, and the underlying privileges are
-- revoked outright (see the bottom of this file). Either alone would do today;
-- both mean the log stays untamperable if one is ever loosened by accident.

-- The two staff references carry no ON DELETE clause, where 0020 and 0029 use
-- ON DELETE SET NULL. Not an oversight and not copyable from them: those
-- columns are nullable and these are NOT NULL, so SET NULL is not available
-- here. The default is RESTRICT, which means a staff row named anywhere in
-- this log can never be hard-deleted — correct for an audit log, where "who
-- did it" must not become erasable by deleting the person, and free in
-- practice because staff are retired with `deleted_at` rather than removed.
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

-- The layer underneath RLS, for the same reason 0054 has one. Supabase's
-- default privileges hand `anon` and `authenticated` full DML on every new
-- table in `public`, so as written above the only thing standing between a
-- client and a forged or erased audit row is the absence of a write policy.
-- That is one `FOR ALL` written where `FOR SELECT` was meant, or one
-- `DISABLE ROW LEVEL SECURITY` run in a hurry, away from being wrong — on the
-- table whose entire purpose is to be the record nobody can tamper with.
--
-- Revoked wholesale and granted back, rather than naming the verbs to remove.
-- `ALL` here is seven privileges, and TRUNCATE is one of them: revoking only
-- INSERT, UPDATE and DELETE would leave a manager able to empty the entire log
-- in one statement, RLS notwithstanding — TRUNCATE does not consult policies.
-- Listing what may stay is the only version of this that cannot be
-- accidentally incomplete.
--
-- `anon` gets nothing back: it has no policy, so its grant was never doing
-- anything except waiting to matter. `service_role` is untouched and still
-- writes the log.
REVOKE ALL    ON mfa_reset_audit FROM anon, authenticated;
GRANT  SELECT ON mfa_reset_audit TO   authenticated;
