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

## Deferred code items (follow-ups)

- [ ] **Customer proof-photo viewing (Supabase Storage).** The order detail
      screen does not yet show pickup/delivery proof photos. Needs a Storage
      read path for a customer's own orders — either extend the bucket SELECT
      policy (see `0008_storage.sql`) to own-order photos, or mint signed URLs
      via a `SECURITY DEFINER` RPC — then render them on `OrderDetailScreen`.
- [ ] **Customer PWA deploy workflow.** If a customer web build is wanted, add a
      `deploy-pwa` workflow variant for `apps/amuwak_customer` (its own
      base-href + `--dart-define` secrets), mirroring the staff PWA deploy.
- [ ] **`/account` screen.** Currently a stub route; a profile/sign-out screen
      is a small follow-up.

## CI

`dart run melos run analyze` and `dart run melos run test` run all three
packages (melos `concurrency: 1`). CI is the source of truth for the full
staff suite; locally, run per-package tests one file at a time (this Windows
host deadlocks two concurrent Flutter build-lock holders).
