// redeem-recovery-code
// -----------------------------------------------------------------------------
// Lets a staff member who has lost their authenticator back in, using a one-time
// recovery code.
//
// A recovery code cannot mint an aal2 session — GoTrue issues aal2 only from a
// verified factor challenge. So redemption DELETES the user's TOTP factor, which
// drops nextLevel to aal1 and stops the challenge appearing. That requires the
// admin API, hence the service-role key, hence this function.
//
// Order is burn-then-delete: the RPC burns the code atomically first. If the
// admin call then fails the user has spent a code and is still locked out, with
// nine left — logged loudly below, because that is the case that strands them.
// The alternative (delete first, burn after) leaves a window where one code is
// accepted twice.
//
// The caller is identified from their own JWT — an aal1 session is expected here
// and is fine, but there is NO anonymous path: an attacker needs the password
// AND a code.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

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
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: factors, error: listErr } =
    await admin.auth.admin.mfa.listFactors({ userId });

  if (listErr) {
    console.error('CODE BURNED BUT LIST FAILED — user may be stuck', {
      userId, message: listErr.message,
    });
    return json({ error: 'Could not complete recovery. Try another code.' }, 500);
  }

  for (const factor of factors?.factors ?? []) {
    if (factor.status !== 'verified') continue;
    const { error: delErr } =
      await admin.auth.admin.mfa.deleteFactor({ userId, id: factor.id });
    if (delErr) {
      console.error('CODE BURNED BUT DELETE FAILED — user is stuck', {
        userId, factorId: factor.id, message: delErr.message,
      });
      return json({ error: 'Could not complete recovery. Try another code.' }, 500);
    }
  }

  return json({ ok: true }, 200);
});
