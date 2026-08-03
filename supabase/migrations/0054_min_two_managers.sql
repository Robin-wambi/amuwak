-- 0054_min_two_managers.sql
-- MFA recovery is manager-mediated: a staff member who loses their
-- authenticator is unlocked by a manager. That only works if a locked-out
-- manager has a colleague, so the estate must never fall to one active manager.
--
-- Enforced by trigger rather than RLS on purpose, and not because RLS is
-- untrustworthy: RLS answers "may this person write the staff table at all",
-- which is a different question from "would this particular write leave the
-- estate below two managers". A policy cannot count the rows that would remain
-- after its own statement. Nor can app code, which any direct PostgREST call
-- bypasses.

-- WARNING for anyone touching auth_staff_role(): 0039 once mapped drivers to
-- 'manager' and 0040 reverted it. staff_manager_write (0007) is the ONLY thing
-- stopping a driver from editing staff rows, and it is that one function body.
-- Reinstating 0039's CASE would silently make the staff table driver-writable,
-- with nothing behind it.

-- The single definition of "active manager", shared by the trigger below and
-- the audit policy in 0055.
--
-- Reads staff.role directly rather than calling auth_staff_role(), which
-- deliberately answers a narrower question: it checks `active` but NOT
-- `deleted_at IS NULL`, so a soft-deleted manager still satisfies it. Recovery
-- authority should not survive a soft delete.
CREATE OR REPLACE FUNCTION is_active_manager(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM staff
     WHERE id = p_id
       AND role = 'manager'
       AND active
       AND deleted_at IS NULL
  )
$$;

REVOKE EXECUTE ON FUNCTION is_active_manager(uuid) FROM public, anon;
GRANT  EXECUTE ON FUNCTION is_active_manager(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION enforce_min_two_managers() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  was_manager boolean;
  still_manager boolean;
  remaining int;
BEGIN
  was_manager := OLD.role = 'manager' AND OLD.active AND OLD.deleted_at IS NULL;

  -- Only changes that REMOVE an active manager are interesting. Without this,
  -- deactivating a driver while the estate sits at one manager would be
  -- blocked, and an estate could never climb back out.
  IF NOT was_manager THEN
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    still_manager :=
      NEW.role = 'manager' AND NEW.active AND NEW.deleted_at IS NULL;
    IF still_manager THEN
      RETURN NEW;  -- a rename or phone change, not a removal
    END IF;
  END IF;

  -- Serialize concurrent removals. Without this, two transactions each
  -- removing a DIFFERENT manager would both count the other's row as still
  -- active, both pass, and jointly drop the estate below the floor. The lock
  -- is transaction-scoped, so it releases on commit or rollback.
  PERFORM pg_advisory_xact_lock(hashtext('staff_min_two_managers'));

  SELECT count(*) INTO remaining
    FROM staff
   WHERE role = 'manager' AND active AND deleted_at IS NULL
     AND id <> OLD.id;

  IF remaining < 2 THEN
    RAISE EXCEPTION
      'At least two active managers are required (this would leave %). '
      'Promote another manager first.', remaining;
  END IF;

  RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE TRIGGER staff_min_two_managers
  BEFORE UPDATE OR DELETE ON staff
  FOR EACH ROW EXECUTE FUNCTION enforce_min_two_managers();
