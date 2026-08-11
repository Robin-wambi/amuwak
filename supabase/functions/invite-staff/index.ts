// invite-staff
// -----------------------------------------------------------------------------
// Manager-only endpoint that invites a new staff member. Runs server-side with
// the service-role key so the privileged Supabase admin invite API is never
// exposed to the client.
//
// Flow:
//   1. Identify the caller from their JWT (Authorization header).
//   2. Confirm the caller is an ACTIVE MANAGER (the security boundary — the
//      Flutter UI only hides the button; this is what actually enforces it).
//   3. Validate the payload and reject a duplicate username.
//   4. createUser({ email_confirm: true }) — creates a confirmed auth user. The
//      manager vouches for the address; the set-password email in step 6 is the
//      real ownership proof.
//   5. Insert the matching staff row (id == auth user id) with the chosen role,
//      BEFORE sending any email so a failed insert rolls back cleanly. If the
//      insert fails, delete the just-created auth user so we don't leave an
//      orphan with no staff row.
//   6. Send a set-password email as a RECOVERY link (resetPasswordForEmail).
//      NOT inviteUserByEmail: invite links emit `signedIn`, so the app would
//      route the new user straight to the dashboard with no password set.
//      Recovery links emit `passwordRecovery`, which the app routes to the
//      Set-password screen (same path as "Forgot password").
//
// Env (provided by Supabase automatically): SUPABASE_URL, SUPABASE_ANON_KEY,
// SUPABASE_SERVICE_ROLE_KEY. Optional: INVITE_REDIRECT_URL (where the invite
// link lands — defaults to the project Site URL when unset).

// Pinned to an exact version so a cold start can't silently pull a different
// 2.x into this security-boundary function. Bump deliberately after testing —
// verify this matches a known-good release on the first deploy.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { corsHeadersFor } from '../_shared/cors.ts';

const ALLOWED_ROLES = ['driver', 'in_shop', 'manager'] as const;
type Role = (typeof ALLOWED_ROLES)[number];

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

Deno.serve(async (req) => {
  // Per-request, because the allow header echoes the caller's origin once an
  // allowlist is configured. The policy and the reasoning behind the '*'
  // default now live in `_shared/cors.ts`, shared with `redeem-recovery-code`
  // so the two cannot drift. `json` closes over it, which keeps every existing
  // call site below unchanged.
  const corsHeaders = corsHeadersFor(req);

  function json(body: unknown, status: number): Response {
    return new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const redirectTo = Deno.env.get('INVITE_REDIRECT_URL') ?? undefined;

  // 1. Identify the caller from their bearer token.
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader) return json({ error: 'Missing authorization' }, 401);

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user: caller },
    error: callerErr,
  } = await callerClient.auth.getUser();
  if (callerErr || !caller) {
    return json({ error: 'Not signed in' }, 401);
  }

  // Service-role client for the privileged reads/writes below.
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 2. The caller must be an active manager.
  const { data: callerStaff } = await admin
    .from('staff')
    .select('role, active')
    .eq('id', caller.id)
    .maybeSingle();
  if (!callerStaff || callerStaff.active !== true ||
      callerStaff.role !== 'manager') {
    return json({ error: 'Only managers can invite staff' }, 403);
  }

  // 3. Validate the payload.
  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Invalid request body' }, 400);
  }

  const email = String(payload.email ?? '').trim().toLowerCase();
  const displayName = String(payload.display_name ?? '').trim();
  const username = String(payload.username ?? '').trim().toLowerCase();
  const role = String(payload.role ?? '') as Role;

  if (!EMAIL_RE.test(email)) return json({ error: 'Enter a valid email' }, 400);
  if (!displayName) return json({ error: 'Display name is required' }, 400);
  if (!username) return json({ error: 'Username is required' }, 400);
  if (!ALLOWED_ROLES.includes(role)) {
    return json({ error: 'Invalid role' }, 400);
  }

  // 3b. Reject a duplicate username before inviting, so we don't create an auth
  // user we'd then have to roll back.
  const { data: existing } = await admin
    .from('staff')
    .select('id')
    .eq('username', username)
    .is('deleted_at', null)
    .maybeSingle();
  if (existing) return json({ error: 'Username already taken' }, 409);

  // 4. Create a confirmed auth user.
  const { data: created, error: createErr } =
    await admin.auth.admin.createUser({ email, email_confirm: true });
  if (createErr || !created?.user) {
    // Most commonly: the email already has an account.
    return json(
      { error: createErr?.message ?? 'Could not create the user' },
      409,
    );
  }
  const userId = created.user.id;

  // 5. Create the staff row keyed to the new auth user — before sending any
  //    email, so a failed insert rolls back with nothing already sent.
  const { error: insertErr } = await admin.from('staff').insert({
    id: userId,
    username,
    display_name: displayName,
    role,
    active: true,
  });
  if (insertErr) {
    // Roll back the orphaned auth user so the manager can retry cleanly. Log a
    // failed cleanup so ops can remove the stray user manually — otherwise an
    // auth user with no staff row would linger silently.
    const { error: deleteErr } = await admin.auth.admin.deleteUser(userId);
    if (deleteErr) {
      console.error('invite-staff: orphan auth-user cleanup failed', {
        userId,
        error: deleteErr.message,
      });
    }
    const duplicate = insertErr.code === '23505';
    return json(
      {
        error: duplicate
          ? 'Username already taken'
          : 'Could not create the staff record',
      },
      duplicate ? 409 : 500,
    );
  }

  // 6. Send the set-password email as a recovery link. Mirrors the app's working
  //    "forgot password" path so Supabase sends its recovery template and the
  //    link fires `passwordRecovery` on click. The account + staff row already
  //    exist, so a send failure is non-fatal — log it and ask the manager to
  //    retry (or the user to use "Forgot password").
  const anon = createClient(supabaseUrl, anonKey);
  const { error: emailErr } = await anon.auth.resetPasswordForEmail(
    email,
    redirectTo ? { redirectTo } : undefined,
  );
  if (emailErr) {
    console.error('invite-staff: set-password email failed', {
      userId,
      error: emailErr.message,
    });
    return json(
      {
        error: 'Account created but the set-password email could not be sent. '
          + 'Ask the user to use “Forgot password”, or try again.',
      },
      502,
    );
  }

  return json({ ok: true, user_id: userId }, 200);
});
