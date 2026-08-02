// reset-staff-mfa
// -----------------------------------------------------------------------------
// Manager-only endpoint that clears a staff member's TOTP factors after they
// lose their authenticator. Runs server-side with the service-role key so the
// privileged admin MFA API is never exposed to the client.
//
// Why this exists: Supabase TOTP has no recovery codes, and nothing we write
// can mint an aal2 session (GoTrue owns the `aal` claim). So recovery cannot be
// "another way to pass the check" — it can only REMOVE the factor and drop the
// account to aal1. deleteFactor signs the target out of all sessions, so they
// land at login, sign in with their password, and enrol again.
//
// Three rules, and the second is what makes this safe rather than a hole:
//   1. Caller is an ACTIVE MANAGER, read from the raw staff.role column.
//      NOT auth_staff_role() — migration 0039 makes that return 'manager' for
//      drivers, so every RLS-style check passes for a rider.
//   2. Caller does not OWE an MFA challenge. A locked-out manager still holds a
//      valid aal1 session; the app hides the UI but the JWT works. Without this,
//      a stolen password alone could strip 2FA off any account and MFA would be
//      decorative. Phrased as "if you have a verified factor, your aal must be
//      aal2" rather than a flat aal2 requirement, so the endpoint is usable
//      while enrolment is still optional and nobody has a factor yet.
//   3. Caller is not the target. A manager at aal2 can already unenrol
//      themselves via MfaService.removeFactor; self-reset here would only muddy
//      the audit trail.
//
// Env (provided by Supabase automatically): SUPABASE_URL,
// SUPABASE_SERVICE_ROLE_KEY. Optional: ALLOWED_ORIGIN.

// Pinned to an exact version so a cold start can't silently pull a different
// 2.x into this security-boundary function. Matches invite-staff.
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

/// Reads a claim out of the bearer token without verifying it. Safe here
/// because getUser() below verifies the signature; this only reads `aal`,
/// which getUser does not surface.
function aalFromJwt(token: string): string | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const padded = parts[1] + '='.repeat((4 - (parts[1].length % 4)) % 4);
    const payload = JSON.parse(
      atob(padded.replace(/-/g, '+').replace(/_/g, '/')),
    );
    return typeof payload.aal === 'string' ? payload.aal : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '');
  if (!token) return json({ error: 'Not signed in' }, 401);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Identify the caller. getUser verifies the token signature.
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) {
    return json({ error: 'Not signed in' }, 401);
  }
  const callerId = userData.user.id;

  let body: { target_staff_id?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Invalid request' }, 400);
  }
  const targetId = body.target_staff_id;
  if (typeof targetId !== 'string' || targetId.length === 0) {
    return json({ error: 'Invalid request' }, 400);
  }

  // Rule 3, cheapest check first.
  if (targetId === callerId) {
    return json({ error: 'You cannot reset your own two-factor here' }, 403);
  }

  // Rule 1: active manager, raw column.
  const { data: caller } = await admin
    .from('staff')
    .select('role, active, deleted_at')
    .eq('id', callerId)
    .maybeSingle();

  const callerIsManager = caller !== null &&
    caller.role === 'manager' && caller.active === true &&
    caller.deleted_at === null;
  if (!callerIsManager) {
    return json({ error: 'Only managers can do that' }, 403);
  }

  // Rule 2: the caller must not owe a challenge of their own.
  const { data: callerFactors } = await admin.auth.admin.mfa.listFactors({
    userId: callerId,
  });
  const callerHasVerified = (callerFactors?.factors ?? []).some(
    (f: { status: string }) => f.status === 'verified',
  );
  if (callerHasVerified && aalFromJwt(token) !== 'aal2') {
    return json(
      { error: 'Complete your own two-factor check first' },
      403,
    );
  }

  // Target must exist as a staff member.
  const { data: target } = await admin
    .from('staff')
    .select('id, display_name')
    .eq('id', targetId)
    .maybeSingle();
  if (target === null) {
    return json({ error: 'Staff member not found' }, 404);
  }

  const { data: targetFactors, error: listError } =
    await admin.auth.admin.mfa.listFactors({ userId: targetId });
  if (listError) {
    return json({ error: 'Could not read their two-factor setup' }, 500);
  }

  const verified = (targetFactors?.factors ?? []).filter(
    (f: { status: string }) => f.status === 'verified',
  );

  for (const factor of verified) {
    const { error: deleteError } = await admin.auth.admin.mfa.deleteFactor({
      id: factor.id,
      userId: targetId,
    });
    if (deleteError) {
      return json({ error: 'Could not clear their two-factor' }, 500);
    }
  }

  // Audit AFTER the deletes, so the log records what actually happened rather
  // than what was attempted.
  await admin.from('mfa_reset_audit').insert({
    actor_staff_id: callerId,
    target_staff_id: targetId,
    factors_cleared: verified.length,
  });

  return json({ factors_cleared: verified.length }, 200);
});
