// redeem-recovery-code
// -----------------------------------------------------------------------------
// Lets a staff member who has lost their authenticator back in, using a one-time
// recovery code.
//
// A recovery code cannot mint an aal2 session — GoTrue issues aal2 only from a
// verified factor challenge. So redemption DELETES every verified MFA factor on
// the account (TOTP is the only kind this app enrols today, but the loop below
// does not assume that), which drops nextLevel to aal1 and stops the challenge
// appearing. That requires the admin API, hence the service-role key, hence
// this function.
//
// Order is burn-then-delete: the RPC burns the code atomically first. The RPC
// itself no longer deletes the caller's remaining codes — see
// `clear_mfa_recovery_codes` in migration 0054. That step now happens here,
// AFTER the factor deletion below has actually succeeded: burning the code and
// then deleting the sibling codes before the admin call is confirmed to have
// worked was the bug this ordering fixes. If the admin call fails, the user has
// spent one code but still has the other nine to retry with — logged loudly
// below, because that is the case that strands them.
//
// The alternative (delete first, burn after) leaves a window where one code is
// accepted twice.
//
// The caller is identified from their own JWT — an aal1 session is expected here
// and is fine, but there is NO anonymous path: an attacker needs the password
// AND a code.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

// A recovery code is 20 hex characters plus 3 dashes (24 chars); normalisation
// also tolerates spaces or lowercase. Nothing legitimate is anywhere near this
// long — reject early so an oversized string never reaches regexp_replace and
// up to ten crypt() calls in the RPC.
const MAX_CODE_LENGTH = 64;

const allowedOrigin = Deno.env.get('ALLOWED_ORIGIN') ?? '*';

const corsHeaders = {
  'Access-Control-Allow-Origin': allowedOrigin,
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Used for every failure after the code has already been burned. Deliberately
// does NOT say "try another code" implying the other nine are still intact —
// they are, but the wording only needs to be honest: the code just used is
// spent, two-factor may still be on, and another code will genuinely work
// now that clearing the siblings happens after factor deletion, not before.
function stuckAfterBurn(): Response {
  return json({
    error: 'That code was accepted, but two-factor could not be turned off. '
      + 'Try another code.',
  }, 500);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return json({ error: 'Not signed in.' }, 401);

  let code: unknown;
  try {
    code = (await req.json())?.code;
  } catch {
    return json({ error: 'Malformed request.' }, 400);
  }
  if (typeof code !== 'string' || code.trim() === '') {
    return json({ error: 'Enter a recovery code.' }, 400);
  }
  if (code.length > MAX_CODE_LENGTH) {
    return json({ error: 'Enter a recovery code.' }, 400);
  }

  // As the CALLER, not the service role: this makes auth.uid() resolve inside
  // the RPC, so no user id is accepted from the request body and there is
  // nothing to spoof.
  const asCaller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userErr } = await asCaller.auth.getUser();
  if (userErr || !userData?.user) return json({ error: 'Not signed in.' }, 401);
  const userId = userData.user.id;

  const { data: accepted, error: rpcErr } =
    await asCaller.rpc('redeem_mfa_recovery_code', { p_code: code });

  if (rpcErr) {
    console.error('redeem rpc failed', { userId, message: rpcErr.message });
    return json({ error: 'Could not check that code. Please try again.' }, 500);
  }
  if (accepted !== true) {
    return json({ error: 'That recovery code is not valid.' }, 400);
  }

  // The code is spent. Now drop the factors it bought removal of.
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: factors, error: listErr } =
    await admin.auth.admin.mfa.listFactors({ userId });

  if (listErr) {
    console.error('CODE BURNED BUT LIST FAILED — user may be stuck', {
      userId, message: listErr.message,
    });
    return stuckAfterBurn();
  }

  // Be defensive about the response shape: the documented shape is
  // `{ factors: [...] }`, but if a future SDK version ever returns a bare
  // array instead, `factors?.factors ?? []` would silently iterate nothing
  // and this function would report success having deleted nothing at all —
  // the one thing this whole path exists to do.
  const factorList = Array.isArray(factors)
    ? factors
    : Array.isArray((factors as { factors?: unknown[] } | null)?.factors)
      ? (factors as { factors: unknown[] }).factors
      : null;

  if (factorList === null) {
    console.error('CODE BURNED BUT FACTOR LIST HAD AN UNEXPECTED SHAPE — '
      + 'user is stuck', { userId, factors });
    return stuckAfterBurn();
  }

  // Zero VERIFIED factors is the goal state, not a failure: an admin may
  // have unenrolled the factor already, or a second device may have won a
  // concurrent redemption race. Either way the challenge will not appear
  // again, which is the only thing this endpoint promises. Conflating "we
  // deleted nothing" with "we failed" used to make the caller retry with the
  // next code, get the same outcome, and burn every code they had without
  // ever being wrong to do so.
  const verifiedFactors = (factorList as { id: string; status: string }[])
    .filter((factor) => factor.status === 'verified');

  for (const factor of verifiedFactors) {
    const { error: delErr } =
      await admin.auth.admin.mfa.deleteFactor({ userId, id: factor.id });
    if (delErr) {
      console.error('CODE BURNED BUT DELETE FAILED — user is stuck', {
        userId, factorId: factor.id, message: delErr.message,
      });
      return stuckAfterBurn();
    }
  }

  // Factor deletion is confirmed (or was never needed). Only now clear the
  // caller's remaining recovery codes — via the ADMIN client, passing the
  // userId already verified from the caller's own JWT above: this RPC is
  // granted to service_role only, not `authenticated`, because it is a
  // destructive primitive with no aal gate of its own (see migration 0054).
  // A failure here is NOT fatal: the user is already back in with their
  // password alone, and the worst case is a stale code sitting unused in the
  // table. Log it and still report success.
  const { error: clearErr } =
    await admin.rpc('clear_mfa_recovery_codes', { p_user: userId });
  if (clearErr) {
    console.error('FACTOR DELETED BUT CLEARING OLD CODES FAILED — '
      + 'non-fatal, old codes may remain', {
      userId, message: clearErr.message,
    });
  }

  return json({ ok: true }, 200);
});
