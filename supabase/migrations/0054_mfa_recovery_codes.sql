-- 0054_mfa_recovery_codes.sql
-- Self-service recovery for a staff member who has lost their authenticator.
--
-- Supabase has no native recovery codes, and a recovery code CANNOT mint an
-- aal2 session — GoTrue issues aal2 only from a verified factor challenge. So
-- redeeming a code means deleting the user's TOTP factor, dropping them back to
-- aal1 so the challenge stops appearing. The factor deletion itself lives in the
-- `redeem-recovery-code` Edge Function: no migration here writes to auth.*, and
-- a locked-out user cannot unenrol themselves (GoTrue requires aal2 to unenrol a
-- verified factor). This migration owns only the secrets.

CREATE TABLE mfa_recovery_codes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash  text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  used_at    timestamptz
);

CREATE INDEX mfa_recovery_codes_unused_idx
  ON mfa_recovery_codes (user_id) WHERE used_at IS NULL;

-- RLS on with DELIBERATELY ZERO POLICIES denies everyone, including the row's
-- owner. Combined with the REVOKE below, the only way in is the two SECURITY
-- DEFINER functions. Nobody ever reads their own hashes.
ALTER TABLE mfa_recovery_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON mfa_recovery_codes FROM anon, authenticated;

-- Mint ten codes, replacing any previous set.
--
-- The aal2 check is the security control the whole feature rests on. Without
-- it: sign in with password (aal1) -> generate -> receive ten plaintext codes ->
-- redeem one -> factor deleted -> two-factor defeated by the password alone.
-- Written as IS DISTINCT FROM so a missing or null claim fails CLOSED.
CREATE FUNCTION generate_mfa_recovery_codes()
RETURNS text[]
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user  uuid := auth.uid();
  v_aal   text := auth.jwt() ->> 'aal';
  v_codes text[] := '{}';
  v_raw   text;
  i       int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'generate_mfa_recovery_codes requires a signed-in caller';
  END IF;
  IF v_aal IS DISTINCT FROM 'aal2' THEN
    RAISE EXCEPTION 'generate_mfa_recovery_codes requires an aal2 session';
  END IF;

  DELETE FROM mfa_recovery_codes WHERE user_id = v_user;

  FOR i IN 1..10 LOOP
    -- 10 bytes = 80 bits, rendered as 20 uppercase hex characters.
    v_raw := upper(encode(extensions.gen_random_bytes(10), 'hex'));
    INSERT INTO mfa_recovery_codes (user_id, code_hash)
      VALUES (v_user, extensions.crypt(v_raw, extensions.gen_salt('bf')));
    -- Stored undashed; the dashes are for the human transcribing it.
    v_codes := array_append(v_codes,
      substr(v_raw,  1, 5) || '-' || substr(v_raw,  6, 5) || '-' ||
      substr(v_raw, 11, 5) || '-' || substr(v_raw, 16, 5));
  END LOOP;

  RETURN v_codes;
END;
$$;

-- Burn one code. Returns false for anything unrecognised — the caller decides
-- what to tell the user, and this must not leak whether a code merely belongs
-- to somebody else.
--
-- bcrypt cannot be looked up by value, so this walks the caller's unused rows.
-- At most ten verifications on a rare path.
CREATE FUNCTION redeem_mfa_recovery_code(p_code text)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_norm text;
  v_id   uuid;
  r      record;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'redeem_mfa_recovery_code requires a signed-in caller';
  END IF;

  -- Accept whatever the user typed: dashes, spaces, lowercase.
  v_norm := upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Za-z]', '', 'g'));
  IF v_norm = '' THEN RETURN false; END IF;

  FOR r IN SELECT id, code_hash FROM mfa_recovery_codes
            WHERE user_id = v_user AND used_at IS NULL
  LOOP
    IF extensions.crypt(v_norm, r.code_hash) = r.code_hash THEN
      v_id := r.id;
      EXIT;
    END IF;
  END LOOP;

  IF v_id IS NULL THEN RETURN false; END IF;

  -- Atomic burn: concurrent redemptions of one code cannot both win.
  UPDATE mfa_recovery_codes SET used_at = now()
   WHERE id = v_id AND used_at IS NULL;
  IF NOT FOUND THEN RETURN false; END IF;

  -- The remaining codes are deliberately NOT deleted here. This function's
  -- caller is the Edge Function, which still has to delete the user's TOTP
  -- factor via the admin API after this returns. If that admin call fails,
  -- the caller must have codes left to retry with — see
  -- `clear_mfa_recovery_codes` below, which the Edge Function calls only
  -- once the factor deletion has actually succeeded. The burned row stays
  -- either way, as an audit trail.
  RETURN true;
END;
$$;

-- Deletes the caller's remaining UNUSED recovery codes. Split out of
-- `redeem_mfa_recovery_code` so the Edge Function can call this only AFTER
-- the TOTP factor deletion it performs via the admin API has succeeded — see
-- that function's ordering note. Operates on auth.uid() only: never accepts
-- a caller-supplied user id, so there is nothing to spoof.
--
-- Only unused rows are deleted (`used_at IS NULL`) so a burned code stays put
-- as the audit trail, same as before this was split out of
-- `redeem_mfa_recovery_code`.
CREATE FUNCTION clear_mfa_recovery_codes()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'clear_mfa_recovery_codes requires a signed-in caller';
  END IF;

  DELETE FROM mfa_recovery_codes WHERE user_id = v_user AND used_at IS NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION generate_mfa_recovery_codes()      FROM public;
GRANT  EXECUTE ON FUNCTION generate_mfa_recovery_codes()      TO authenticated;
REVOKE EXECUTE ON FUNCTION redeem_mfa_recovery_code(text)     FROM public;
GRANT  EXECUTE ON FUNCTION redeem_mfa_recovery_code(text)     TO authenticated;
REVOKE EXECUTE ON FUNCTION clear_mfa_recovery_codes()         FROM public;
GRANT  EXECUTE ON FUNCTION clear_mfa_recovery_codes()         TO authenticated;
