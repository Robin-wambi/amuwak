# Staff invites & email + password auth

The app uses **invite-only** onboarding with **email + password** sign-in. There
is no public sign-up: a manager invites a teammate, who clicks an emailed link to
set their own name and password. Returning users stay signed in — the persisted
Supabase session lands them straight on the dashboard.

## How it fits together

- **Login** — `signInWithEmailPassword` (real email + password). "Forgot
  password?" sends a reset link. See [auth_service.dart](../lib/src/auth/auth_service.dart).
- **AuthGate** — root widget that routes Login / Set-password / Dashboard from the
  auth state. See [auth_gate.dart](../lib/src/auth/auth_gate.dart).
- **Invite (manager only)** — Account tab → "Invite staff" opens a form that calls
  the `invite-staff` Edge Function via [invite_staff_service.dart](../lib/src/staff/invite_staff_service.dart).
- **Edge Function** — [supabase/functions/invite-staff/index.ts](../supabase/functions/invite-staff/index.ts)
  authenticates the caller as a manager, then uses the service-role key to create
  a confirmed auth user, insert their `staff` row (`id == auth.users.id`, role
  defaults to `driver`), and email them a set-password link. The UI gating is
  convenience only — this function is the real boundary. New roles must be one of
  `driver | in_shop | manager` (migration 0002).
  - The set-password email is sent as a **recovery** link
    (`resetPasswordForEmail`), not `inviteUserByEmail`. Invite links emit a
    `signedIn` event, which would route the new user straight to the dashboard
    with no password set; recovery links emit `passwordRecovery`, which the app
    routes to the Set-password screen (the same path as "Forgot password").
- **Set name + password** — on first login the invitee confirms/edits their own
  display name (pre-filled with what the manager entered) and chooses a password.
  The name write goes through the `set_my_display_name` RPC (migration 0028),
  which is column-scoped so a non-manager can rename only themselves.

## One-time setup (Supabase dashboard / CLI)

These cannot be done from app code — an operator must run them:

1. **Deploy the function** (the service-role secret is injected automatically as
   `SUPABASE_SERVICE_ROLE_KEY`; never put it in the app):

   ```sh
   supabase functions deploy invite-staff
   ```

   Optionally set where invite/reset links land (defaults to the project Site
   URL): `supabase secrets set INVITE_REDIRECT_URL=https://<your-web-app>`

2. **Auth settings** (Authentication → Providers / URL config):
   - Enable email confirmations.
   - Set **Site URL** and add the web app origin to **Redirect URLs**.
   - The **Reset password** email template is the email new invitees receive
     (onboarding sends a recovery link), so word it as a welcome / "set your
     password" message, not just a reset.

     **Its link must be a token hash, not `{{ .ConfirmationURL }}`:**

         {{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=recovery

     Mirror `supabase/templates/recovery.html`. This is not cosmetic — the
     default emits a link tied to the flow of whichever client requested it,
     and `invite-staff` requests via supabase-js (implicit) while the apps run
     PKCE. Mismatched, `supabase_flutter` ignores the link entirely: no
     exchange, no error, no event, and the invitee lands on the login screen
     with nothing explaining why. A token hash belongs to neither flow, so it
     works for every client. On the staff PWA it also keeps the token out of
     the URL fragment, which would otherwise collide with the app's hash
     routes.
   - Raise the **recovery link / OTP expiry** (Authentication → Settings) to a
     window long enough for a new hire to act — recovery links default to a much
     shorter expiry than the old invite links.
   - Set the **minimum password length to 8** (Authentication → Policies) to match
     the client's 8-char check in [set_password_screen.dart](../lib/src/auth/set_password_screen.dart).
     If Supabase's minimum is lower the client still enforces 8; if it's set
     higher, users hit a raw server error instead of a clean field message.

3. **Bootstrap a manager.** Only managers can invite, so seed the first one:
   create an auth user (Authentication → Users → Add user, set a password), then
   insert a matching `staff` row with the same `id` and `role = 'manager'`.

## End-to-end check

1. Sign in as the seeded manager → Account → **Invite staff** → invite a test
   email as `driver`. Confirm the set-password email arrives and a `staff` row
   exists (`active = true`, `role = driver`).
2. Open the emailed link → **Set name & password** (name pre-filled with what the
   manager entered, editable) → submit → land on the dashboard with the chosen
   name, driver-scoped data and `user_role = driver` in the JWT.
3. Sign out → **Forgot password?** → complete the reset → sign in again.
4. Negative: a non-manager calling the function is rejected (403); a duplicate
   username/email returns a clear error.

## Recovering a staff member who lost their authenticator

Any active manager can do this from the app: **Account → Staff**, tap the
person, confirm. Clearing the factor ends the sessions that were elevated by
it; in practice, the target signs in again with their password alone and is
prompted to enrol a new authenticator (the exact session behaviour is
confirmed by the function's manual deployment check, not by anything in this
repo).

Managers can reset each other, which is why the database requires at least two
active managers (migration 0055). Nobody can reset themselves.

A manager who has enrolled their own TOTP must complete their own two-factor
check (be at `aal2`) before they can clear someone else's — if you're a
manager sitting at `aal1` with a factor already enrolled, you'll see "Complete
your own two-factor check first." This is deliberate: without it, a stolen
password alone would be enough to disable MFA on any account.

**If you are down to one manager**, no one in the app can unlock them. Recover
from the Supabase dashboard: Authentication → Users → the user → remove the MFA
factor. Avoid this situation by keeping a second manager. Note the database will
refuse to demote, deactivate or delete a manager that would leave fewer than
two — promote a replacement first.

Note the in-app way to add a manager is to **invite** one with the `manager`
role — role changes are not editable from the app.

**Deploying, in this order:**

```bash
supabase db push                              # 0055, 0056
supabase functions deploy reset-staff-mfa
# then merge — the staff app auto-deploys on push to main
```

Order matters. If the function goes out before the migrations, every reset
still returns success but writes no audit row, because `mfa_reset_audit` does
not exist yet — and that failure is only logged server-side, where nobody is
watching.

No extra secrets: it uses the `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
that Supabase injects automatically. `ALLOWED_ORIGINS` is optional and shared
with the other functions — see `supabase/functions/_shared/cors.ts`.

**Reading the audit log.** Every reset that *happened* is recorded. Managers can
query it:

```sql
select a.created_at, actor.display_name as cleared_by,
       target.display_name as cleared_for, a.factors_cleared
  from mfa_reset_audit a
  join staff actor  on actor.id  = a.actor_staff_id
  join staff target on target.id = a.target_staff_id
 order by a.created_at desc;
```

**Reading the refusals.** An attempt that was *rejected* is not in that table —
both its subject columns are `NOT NULL REFERENCES staff(id)`, so an unknown
target or a caller with no staff row could not be written there at all, and the
rest would arrive as `factors_cleared = 0` rows indistinguishable from a real
reset of somebody with no authenticator. Refusals go to the function log
instead:

```bash
supabase functions logs reset-staff-mfa | grep 'reset-staff-mfa: denied'
```

`reason` is one of `self-target`, `caller-not-active-manager`,
`caller-owes-mfa-challenge`, `target-not-found`. The second and third are the
ones to care about: repeated `caller-owes-mfa-challenge` means somebody holds a
manager's password but cannot pass that manager's second factor.
