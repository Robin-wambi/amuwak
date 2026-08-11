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
--
-- Deliberately not constant-time: the loop exits on the first match. The only
-- timing that varies is a SUCCESSFUL redemption, which already requires holding
-- a valid code — a wrong code always walks every unused row. The query is also
-- scoped to auth.uid(), so the most this can leak is the position of a caller's
-- own code among their own rows. Nothing an attacker does not already have.
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

-- Deletes a user's remaining UNUSED recovery codes. Split out of
-- `redeem_mfa_recovery_code` so the Edge Function can call this only AFTER
-- the TOTP factor deletion it performs via the admin API has succeeded — see
-- that function's ordering note.
--
-- Takes `p_user` instead of resolving auth.uid() itself, and is granted ONLY
-- to service_role (see the REVOKE/GRANT below) — NOT to `authenticated`. This
-- is a destructive primitive: an aal1 session (password known, authenticator
-- not) has no business being able to wipe someone's break-glass codes, and
-- unlike `generate_mfa_recovery_codes` there is no aal2 check to gate it with
-- — clearing has to run on both the redeem path (aal1, by design: that is
-- the whole point of a recovery code) and could not tell an aal1 redeemer
-- from an aal1 attacker by aal alone. So the caller-supplied p_user is safe
-- ONLY because the grant restricts who can pass one at all: the Edge
-- Function calls this with the SERVICE-ROLE client, passing the userId it
-- already verified from the caller's own JWT via auth.getUser() — never a
-- value taken from the request body. If this is ever re-granted to
-- `authenticated`, that safety property is gone: anyone could pass anyone
-- else's uuid. Do not re-grant it.
CREATE FUNCTION clear_mfa_recovery_codes(p_user uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  IF p_user IS NULL THEN
    RAISE EXCEPTION 'clear_mfa_recovery_codes requires a user id';
  END IF;

  DELETE FROM mfa_recovery_codes WHERE user_id = p_user AND used_at IS NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION generate_mfa_recovery_codes()      FROM public;
GRANT  EXECUTE ON FUNCTION generate_mfa_recovery_codes()      TO authenticated;
REVOKE EXECUTE ON FUNCTION redeem_mfa_recovery_code(text)     FROM public;
GRANT  EXECUTE ON FUNCTION redeem_mfa_recovery_code(text)     TO authenticated;
-- `anon` MUST be in this list. Supabase's default privileges grant EXECUTE on
-- every new function in `public` to BOTH anon and authenticated, and revoking
-- from `public` does not touch either of those explicit grants. The other two
-- functions above survive that because they raise on a null auth.uid(); this
-- one takes a caller-supplied uuid with no caller check by design, so the
-- grant is its ONLY protection. Omitting anon made it an unauthenticated,
-- remotely-callable way to wipe any user's break-glass codes over PostgREST
-- using the anon key that ships in the client — verified exploitable before
-- this line was corrected.
REVOKE EXECUTE ON FUNCTION clear_mfa_recovery_codes(uuid)
  FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION clear_mfa_recovery_codes(uuid)     TO service_role;
