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
   - Review the **Reset password** email template — this is the email new
     invitees receive (onboarding sends a recovery link), so word it as a
     welcome / "set your password" message, not just a reset.
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
person, confirm. Their TOTP factor is cleared, they are signed out everywhere,
and they sign in with their password and enrol a new authenticator.

Managers can reset each other, which is why the database requires at least two
active managers (migration 0054). Nobody can reset themselves.

**If you are down to one manager**, no one in the app can unlock them. Recover
from the Supabase dashboard: Authentication → Users → the user → remove the MFA
factor. Avoid this situation by keeping a second manager. Note the database will
refuse to demote, deactivate or delete a manager that would leave fewer than
two — promote a replacement first.

**Deploying the function:**

```bash
supabase functions deploy reset-staff-mfa
```

No extra secrets: it uses the `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
that Supabase injects automatically.
