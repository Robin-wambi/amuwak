# amuwak

Monorepo for the Amuwak laundry business:

- `apps/amuwak_staff` — the staff/rider app (Flutter; also a PWA on GitHub Pages).
- `apps/amuwak_customer` — the customer app (Flutter; a PWA on Cloudflare Pages).
- `packages/amuwak_core` — code both apps share: design system, domain models,
  pricing, auth, and the Supabase repositories.
- `supabase/` — the single migration history and pgTAP tests both apps depend on.

One pub workspace, one lockfile, one backend — see `docs/` for deployment and
hardening notes.
