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
> exactly the set of verbs that have at least one RLS policy on that table —
> counting a grant on any single column as holding that verb. `anon` holds
> nothing. `service_role` holds the four CRUD verbs, less any a table's own
> migration deliberately withholds. Nobody but the owner holds TRUNCATE,
> REFERENCES, TRIGGER or MAINTAIN.

**The column clause was added during implementation, and it is load-bearing.**
`0046_customer_rls.sql:84-85` deliberately does `REVOKE UPDATE ON order_messages`
followed by `GRANT UPDATE (read_at)`, because RLS gates which *rows* a caller may
update and never which *columns* — without it, anyone who can mark a message read
could also rewrite a staff reply's body or forge its sender. `has_table_privilege`
does not see column grants, so the invariant as first written read that correct,
deliberate arrangement as a missing grant and would have demanded the grant be
widened. Any future statement of this rule must keep the column clause.

**`service_role` is not uniform, for the same kind of reason.**
`mfa_recovery_codes` gets nothing — `0054` states its two `SECURITY DEFINER`
functions are the only way in, and both Edge Function call sites go through
them. `mfa_reset_audit` gets `SELECT, INSERT` only: whoever holds the
service-role key is the actor that table logs, so UPDATE or DELETE would let
them erase the record of the reset they just performed.

Both directions of the equality carry weight:

- A **verb with a policy but no grant** is dead code. The policy can never fire,
  and the intent it documents is a lie.
- A **grant with no policy** is blocked today by RLS, and only by RLS. That is
  precisely the arrangement that left TRUNCATE exposed.

Every app table already has RLS enabled (`0007_rls.sql:23-31` and each later
table's own migration), which is what makes tightening safe: any verb this
removes was already refused at the row level.

The invariant needs **no exception list**, and this survived contact with the
schema. The four tables that look like exceptions all satisfy it naturally:
`order_code_counters` and `mfa_recovery_codes` have no policy and receive no
grant for `authenticated` (empty equals empty); `mfa_reset_audit` has one SELECT
policy and one SELECT grant; and `order_messages` satisfies its UPDATE policy
through the column grant above. A table that needed naming in the test would be
evidence the design is wrong — the exception list was the thing worth avoiding,
and it stayed avoided.

## The migration

Three parts, in order.

**1. Revoke wholesale, per table.**

```sql
REVOKE ALL ON <table> FROM anon, authenticated, service_role;
```

Not a list of verbs to remove. `ALL` is eight privileges and the ones that
matter here are the ones a hand-written list forgets. This generalises the
lesson from `0056_mfa_reset_audit.sql`, where naming `INSERT, UPDATE, DELETE`
would have left TRUNCATE behind.

**2. Grant back, per table.**

```sql
GRANT <policy verbs>              ON <table> TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON <table> TO service_role;
```

`service_role` gets the four CRUD verbs and no more — TRUNCATE excluded because
nothing uses it. It bypasses RLS by design and its key never reaches a browser,
so its blast radius is already the whole database. Without this grant all three
Edge Functions (`invite-staff`, `reset-staff-mfa`, `redeem-recovery-code`) break
on any newly provisioned project.

Two tables take less than the four, and both are named above: `mfa_recovery_codes`
takes nothing, `mfa_reset_audit` takes `SELECT, INSERT`. Where a table's own
migration argues for a narrower server surface, that argument wins — this rule
is a floor for what the server needs, not a ceiling on what a table may refuse.

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
   its policies name, with `FOR ALL` expanding to all four, and a grant on any
   single column counting as holding that verb.
2. `anon` holds no privilege on any table in `public`.
3. No client role holds TRUNCATE, REFERENCES, TRIGGER or MAINTAIN on any table
   in `public`. (All four, not TRUNCATE alone: the other three are equally
   ungated by RLS, and checking one of four would let the rest arrive unnoticed.)
4. Default privileges for future tables are empty for `anon`, `authenticated`
   and `service_role`.

Nothing asserts `service_role`, deliberately: a fifth assertion would have to
name `mfa_recovery_codes` in an allowlist, which forfeits the no-exception-list
property above. The cost is that a forgotten server-side grant surfaces as a
`42501` in an Edge Function rather than a red CI job — stated plainly in
`docs/staff-invites.md` so nobody assumes otherwise.

Generic assertions stay true as the schema grows. Add a table and forget its
grants and assertion 1 fails; add a grant no policy backs and assertion 1 fails
from the other side. Sixteen hand-written per-table assertions would rot the
first time somebody added a seventeenth table.

These run in the `db-tests` CI job, added on this same branch. Note that pgTAP
had never run in CI at all before it, so this suite is the only thing standing
behind the invariant — and it only ever proves the migration against a *fresh*
database. It cannot prove the production path, which is why the post-push
verification below is mandatory rather than optional.

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

Production is at `0056` and fully migrated as of 2026-08-12: `supabase
migration list` showed it at `0053` that day, and `0054`, `0055` and `0056`
were applied immediately after. This migration is therefore a single
`supabase db push` of one migration once merged, not the tail of a larger
backlog — see `docs/superpowers/plans/2026-08-12-table-privilege-grants.md`'s
own Rollout section, which reflects the same up-to-date state.

## Sequencing — resolved

As designed, the number depended on merge order: PR #106 owned `0055` and `0056`
and was unmerged, so landing this first would have collided with it — the
duplicate-prefix failure that silently skipped columns in the 0026 incident.

**What happened:** #106 was merged on 2026-08-12, this branch was rebased onto
the result, and the grant matrix was regenerated so `mfa_reset_audit` was picked
up rather than special-cased. `0057` is the settled number.

The pgTAP CI job was originally its own PR (#112). This branch is stacked on it
and contains its commit, so the workflow and the fix that makes it pass land
together and no knowingly-red PR is ever merged. **#112 is superseded — close
it, do not merge it**, or the workflow is installed twice.

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
