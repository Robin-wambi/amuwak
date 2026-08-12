# Explicit table privileges — design

**Date:** 2026-08-12
**Status:** approved, not yet implemented
**Migration:** `0057_table_grants.sql` (see *Sequencing* — the number depends on merge order)

## The problem

No migration in this repo grants a table privilege to a client role. Every
`GRANT` to `anon`, `authenticated` or `service_role` in `supabase/migrations` is
`EXECUTE` on a function. (`0015_powersync_replication.sql` did grant `SELECT ON
ALL TABLES`, but to a dedicated `powersync` role that `0016` revoked and
dropped.) Client access to tables has always come from Supabase's *default*
privileges — something the vendor sets on the schema, that lives nowhere in this
repository and is not pinned to a version.

Supabase has since narrowed that default. Measured on a fresh stack in CI
against the same migrations that run in production:

```
pg_default_acl, grantor postgres, objtype r (tables), schema public

  fresh stack (CI)   {postgres=arwdDxtm/postgres, anon=Dxtm/postgres,
                      authenticated=Dxtm/postgres, service_role=Dxtm/postgres}

  production-era     {postgres=arwdDxtm/postgres, anon=arwdDxtm/postgres,
                      authenticated=arwdDxtm/postgres, service_role=arwdDxtm/postgres}
```

`a r w d` — INSERT, SELECT, UPDATE, DELETE — are gone. `D x t m` — TRUNCATE,
REFERENCES, TRIGGER, MAINTAIN — remain. Confirmed directly:
`has_table_privilege('authenticated', 'public.orders', …)` is false for all four
CRUD verbs on a fresh stack.

Two consequences follow.

**The migrations cannot rebuild a working database.** Provision a new Supabase
project from `supabase/migrations` today and `authenticated` can neither read
nor insert an order. Disaster recovery, a staging environment and a fork are all
affected. It is invisible in production only because that project predates the
change. It is what makes six pgTAP files fail in CI while passing on a
contributor's older local stack.

**`authenticated` holds TRUNCATE on every table, on both old and new stacks.**
TRUNCATE does not consult row-level policies, so RLS does no work here at all.
This is the hole found in `mfa_reset_audit` during PR #106, except it is the
whole schema rather than one table, and the narrowed default *keeps* it.

Severity, stated honestly: defence-in-depth, not an open door. PostgREST exposes
no TRUNCATE verb, and a client cannot open a connection as `authenticated` — the
role is assumed server-side after JWT validation. Reaching it needs a
`SECURITY INVOKER` function that executes caller-controlled SQL. No such audit
has been done. The grant is nonetheless real and nothing in the repo removes it.

## The invariant

> For every table in `public`, the privileges held by `authenticated` are
> exactly the set of verbs that have at least one RLS policy on that table.
> `anon` holds nothing. `service_role` holds the four CRUD verbs. Nobody but the
> owner holds TRUNCATE, REFERENCES, TRIGGER or MAINTAIN.

Both directions of the equality carry weight:

- A **verb with a policy but no grant** is dead code. The policy can never fire,
  and the intent it documents is a lie.
- A **grant with no policy** is blocked today by RLS, and only by RLS. That is
  precisely the arrangement that left TRUNCATE exposed.

Every app table already has RLS enabled (`0007_rls.sql:23-31` and each later
table's own migration), which is what makes tightening safe: any verb this
removes was already refused at the row level.

The invariant needs **no exception list**. The three tables that look like
exceptions satisfy it naturally — `order_code_counters` and
`mfa_recovery_codes` have no policy and receive no grant (empty equals empty),
and `mfa_reset_audit` has one SELECT policy and one SELECT grant. A table that
required an exception would be evidence the design is wrong.

## The migration

Three parts, in order.

**1. Revoke wholesale, per table.**

```sql
REVOKE ALL ON <table> FROM anon, authenticated, service_role;
```

Not a list of verbs to remove. `ALL` is seven privileges and the ones that
matter here are the ones a hand-written list forgets. This generalises the
lesson from `0056_mfa_reset_audit.sql`, where naming `INSERT, UPDATE, DELETE`
would have left TRUNCATE behind.

**2. Grant back, per table.**

```sql
GRANT <policy verbs>              ON <table> TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON <table> TO service_role;
```

`service_role` gets the four CRUD verbs and no more. It bypasses RLS by design
and its key never reaches a browser, so its blast radius is already the whole
database; the point of excluding TRUNCATE is that nothing uses it. Without this
grant all three Edge Functions (`invite-staff`, `reset-staff-mfa`,
`redeem-recovery-code`) break on any newly provisioned project.

`anon` is granted nothing on any table.

**3. Close the defaults for future tables.**

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated, service_role;
```

A new table then starts with zero client access and must state its grants. The
failure mode of forgetting is loud and lands in CI, which is the right direction
for it to fail.

### The matrix is generated, not transcribed

The authoritative source is `pg_policies` on a fully-migrated database, dumped
during implementation and turned into the grant list mechanically.

The policy set churns: `0010_tighten_orders_rls.sql` drops and recreates
`orders_insert` and `orders_update`, and `0024_gate_pricing_writes.sql` does the
same for three pricing policies. That churn happens to be verb-preserving, so a
hand-derived matrix would land in the right place today — but reading 56
migrations of drop-and-recreate and transcribing the result is how a wrong grant
gets in, and the mistake would be invisible until something broke.

## Verification

A new pgTAP file, written generically rather than as per-table assertions:

1. For every table in `public`, the verbs `authenticated` holds equal the verbs
   its policies name, with `FOR ALL` expanding to all four.
2. `anon` holds no privilege on any table in `public`.
3. No role other than the owner holds TRUNCATE on any table in `public`.
4. Default privileges for future tables are empty for `anon`, `authenticated`
   and `service_role`.

Generic assertions stay true as the schema grows. Add a table and forget its
grants and assertion 1 fails; add a grant no policy backs and assertion 1 fails
from the other side. Sixteen hand-written per-table assertions would rot the
first time somebody added a seventeenth table.

These run in the `db-tests` CI job (PR #112). Note that pgTAP has never run in
CI before that PR, so this suite is the only thing standing behind the
invariant.

## Rollout

Production currently holds the permissive `arwdDxtm` defaults, so this migration
**narrows**. That is safe by construction: every verb it removes from
`authenticated` is one with no policy, already refused by RLS. Expect no
behavioural change and one genuine reduction, the TRUNCATE exposure.

**To verify before applying:** `anon` loses its table grants outright. Customer
signup runs through a `SECURITY DEFINER` RPC (`0042_customer_signup_rpc.sql`),
which executes as its owner and is unaffected — but confirm no anon-facing path
reads a table directly before taking that away.

**After applying:** re-run the `pg_default_acl` and `relacl` queries against
production and confirm the end state matches the invariant. That query is the
evidence that found the problem; it is also the evidence that closes it.

This migration sits at the end of the pending queue. Production was last
verified at tracker 0029, so it cannot be applied without also applying
everything between. This design does not make that backlog worse and does not
address it.

## Sequencing

The migration number depends on merge order. PR #106 owns `0055` and `0056` and
is not merged. Landing this first would collide with it — the duplicate-prefix
failure that silently skipped columns in the 0026 incident. Merge #106 first and
number this `0057`.

Order: **#106 → this → #112 goes green.** PR #112 stays red until this lands,
because its six failures are this problem and nothing else.

## Out of scope

- **Sequences.** The default grants `authenticated` `w` on sequences and
  `nextval()` accepts UPDATE *or* USAGE, so the default-privilege revoke is
  scoped `ON TABLES`. Extending it to sequences would break inserts that depend
  on a sequence default for no security gain — a sequence leaks nothing but its
  own counter.
- **`storage.objects` / `storage.buckets`.** Different owner
  (`supabase_storage_admin`) and a different default-privilege chain.
  `0052_customer_uploads_storage_test.sql` passes in CI, so there is no evidence
  of a problem there.
- **Function `EXECUTE` grants.** Already explicit throughout the migrations.
  That layer was never broken.
- **Auditing for a reachable TRUNCATE.** Whether any `SECURITY INVOKER` function
  executes caller-controlled SQL is a separate audit. This migration removes the
  privilege regardless of whether a path to it exists.
- **The migration backlog on production.** Pre-existing and much larger than
  this change.
