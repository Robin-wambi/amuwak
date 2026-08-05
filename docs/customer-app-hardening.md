# Customer App — Task 10 Hardening Checklist

Status of the Phase C–F hardening pass. Code-side items verifiable without a
live environment are done; the rest need a real Supabase project + devices.

## Done (code / static)

- **Attribution audit — PASS.** Staff write paths use the *logged-in* staff's
  id (`currentUserIdProvider`) as `actorStaffId`; nothing renders an order's
  `created_by` by joining it to `staff.active`, so the inactive
  `Customer App` sentinel (id `…a001`) is stored safely and never assumed to be
  an active staff member. The staff order card instead surfaces a "Placed via
  app" badge for `intake_method = 'customer_app'` orders.
- **Analyze — clean** across `amuwak_core`, `amuwak_staff`, and
  `amuwak_customer` (`flutter analyze` at the workspace root).
- **Customer never mutates status/price** — enforced twice: no update path in
  `CustomerOrdersRepository`, and RLS has no customer UPDATE policy on `orders`
  (migration 0046). The UI offers no such control.

## Needs the live Supabase env (manual)

- [ ] **RLS pen-test.** Sign in as customer B; via direct PostgREST calls try to
      read/insert/patch customer A's order and messages. Expect zero rows /
      `42501`. Backs up the pgTAP denied-access tests (Phase B) with a real JWT.
- [ ] **Signup round-trip.** Register a new customer (email + password),
      confirm `link_or_create_customer` runs on the first session and the
      `customer` role claim lands after `refreshSession()`, and the app routes
      to `/`. (Supabase ops — email signups on, email confirmation off — are
      already configured.)
- [ ] **Estimate ↔ final reconciliation.** Place an order as a customer; have
      staff set the final weight in the staff app; confirm the customer's price
      updates live (stream re-emit) and the "Estimate" badge flips to "Final".
- [ ] **Two-way chat.** Customer sends on an order; staff sees it via the
      order-details chat action and replies; customer's inbox shows the unread
      staff message and the reply lands in the order chat.
- [ ] **Confirm the access-token hook fires on the local stack.** `config.toml`
      now registers `public.custom_access_token_hook`, but that was only checked
      as far as the CLI parsing it — Docker was unavailable. Run
      `supabase start -x storage-api,imgproxy --ignore-health-check`, sign in,
      and decode the JWT: `user_role` must be present. If it is missing the
      whole role-routing policy is inert locally while still working in prod,
      which is the worst version of this bug to debug.

## Dual staff + customer accounts (needs a decision, sized by one query)

`custom_access_token_hook` resolves the staff branch first (`0043`, and staff
must be `active = true`), so a user who is active staff **and** has a live
`customers` row reads as staff. Since PR #103 that pins them to
`kStaffAccountRoute` permanently.

Before #103 those users reached the customer app and it worked — they have a
`customers` row, so `auth_customer_id()` resolves and their orders load. So this
is a behavioural regression for that population, not merely a new restriction.
The notice tells them to sign out and sign up with a personal email, which
works but strands the order history on the old row.

Size it first — the fix is only worth building if this returns rows:

```sql
select s.id, s.role, c.id as customer_id
  from public.staff s
  join public.customers c on c.auth_user_id = s.id
 where s.active = true
   and c.deleted_at is null;
```

- **Zero rows** → no action. Staff having a separate personal customer account
  is the intended shape, and the notice already says so.
- **Any rows** → decide between:
  1. *Let them through.* Add a separate `is_customer` boolean claim in the hook
     (leaving `user_role` alone, so the staff app is untouched) and let
     `customerAuthRedirect` admit a staff role that also carries
     `is_customer: true`. Costs a migration and a router branch.
  2. *Migrate them off.* Keep the current routing and re-point those
     `customers` rows at a personal auth user, so the history follows them.

Whichever way it goes, `customerAuthRedirect` deserves a test pinning the
decision — right now nothing documents that a dual account is deliberately
excluded.

## Deferred code items (follow-ups)

- [ ] **Customer proof-photo viewing (Supabase Storage).** The order detail
      screen does not yet show pickup/delivery proof photos. Needs a Storage
      read path for a customer's own orders — either extend the bucket SELECT
      policy (see `0008_storage.sql`) to own-order photos, or mint signed URLs
      via a `SECURITY DEFINER` RPC — then render them on `OrderDetailScreen`.
- [x] **Customer PWA deploy workflow.** Done — ships to Cloudflare Pages via
      `.github/workflows/deploy-customer-pwa.yml` (GitHub Pages serves one site
      per repo and the staff PWA owns it). One-time Cloudflare setup and the
      post-deploy sanity checks are in `docs/customer-pwa-deploy.md`.
- [x] **`/account` screen.** Done — `account/profile_screen.dart` (name, phone,
      email, sign out) replaced the stub route.

## CI

`dart run melos run analyze` and `dart run melos run test` run all three
packages (melos `concurrency: 1`). CI is the source of truth for the full
staff suite; locally, run per-package tests one file at a time (this Windows
host deadlocks two concurrent Flutter build-lock holders).
