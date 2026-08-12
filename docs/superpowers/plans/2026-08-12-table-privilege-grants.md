# Explicit Table Privileges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `supabase/migrations` sufficient to rebuild a working database, and remove the TRUNCATE privilege that `authenticated` holds on every table.

**Architecture:** One migration, `0057_table_grants.sql`, that revokes all privileges from the three client roles on every table in `public`, grants back exactly the verbs each table's RLS policies name, and closes the default privileges so future tables start with nothing. One pgTAP file asserting that invariant generically, so it stays true as the schema grows.

**Tech Stack:** PostgreSQL 17 (Supabase), pgTAP, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-12-table-privilege-grants-design.md`

## Global Constraints

- **Migration number is `0057`.** Production is at `0056` as of 2026-08-12; `0055` and `0056` belong to PR #106 and are already applied. Do not renumber.
- **The branch must be stacked on `ci/pgtap-in-ci`.** That branch (PR #112) adds the `db-tests` workflow. Without it this work has no way to run pgTAP at all — see *Why CI is the test runner*.
- **`ALTER DEFAULT PRIVILEGES` can only target `FOR ROLE postgres`.** Migrations run as `postgres`, which is not a member of `supabase_admin` and cannot alter its defaults. This is a real limitation, not an omission — document it in the migration.
- **`mfa_recovery_codes` is excluded from the `service_role` grants.** `0054` states that the only way into that table is its two `SECURITY DEFINER` functions, and both Edge Function call sites go through them. Granting `service_role` direct CRUD would quietly falsify that claim.
- **`mfa_reset_audit` must receive `service_role` INSERT.** `reset-staff-mfa/index.ts` writes it directly with the service-role client, not through a function. Miss this and every MFA reset silently stops writing its audit row.
- Every statement is idempotent-safe to re-run in a fresh database; this migration is never applied twice to the same one.

## Why CI is the test runner

`supabase db reset` cannot complete on the current development machine — the db container never clears its health check — so pgTAP cannot be run locally there. The `db-tests` job added by PR #112 starts a full stack, applies every migration and runs `pg_prove` in about two minutes, which is the fastest reliable loop available.

That makes the TDD cycle: **write the test → push → watch the job go red → write the migration → push → watch it go green.** Slower than a local run, and still a genuine red-then-green.

If you have a working local stack, `supabase test db` is equivalent and faster. Verify with `supabase test db` before pushing if so.

## File Structure

| File | Responsibility |
|---|---|
| `supabase/migrations/0057_table_grants.sql` (create) | Revoke, grant back, close defaults. The only file that changes privileges. |
| `supabase/tests/0057_table_grants_test.sql` (create) | The four generic invariant assertions. Never names a table. |
| `docs/staff-invites.md` (modify) | One paragraph: new tables need an explicit `GRANT`. |

---

### Task 1: The failing invariant test

**Files:**
- Create: `supabase/tests/0057_table_grants_test.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: the four assertions Task 2 must satisfy. No SQL identifiers are exported.

- [ ] **Step 1: Stack the branch on the CI workflow branch**

Without this the `db-tests` job does not exist on your branch and nothing below can be verified.

```bash
git fetch origin
git rebase --onto origin/ci/pgtap-in-ci origin/main feat/table-privilege-grants
```

Confirm the workflow is present:

```bash
ls .github/workflows/db-tests.yml
```

Expected: the file exists.

- [ ] **Step 2: Write the test**

Create `supabase/tests/0057_table_grants_test.sql`:

```sql
-- 0057_table_grants_test.sql
-- The privilege layer and the policy layer must agree. A verb with a policy and
-- no grant is dead code; a grant with no policy is held back by RLS alone,
-- which is how `authenticated` kept TRUNCATE on every table for so long.
--
-- Deliberately generic. Naming tables here would mean a seventeenth table could
-- be added with no grants and no failure — the exact gap this file exists to
-- close.
BEGIN;
SET search_path TO extensions, public;

SELECT plan(4);

-- 1. The invariant itself, in both directions. `is_empty` rather than a count,
-- because on failure it prints the offending (table, verb) rows and a count
-- prints "have 3 want 0".
SELECT is_empty($$
  WITH policy_verbs AS (
    SELECT tablename::text AS tbl,
           unnest(CASE WHEN cmd = 'ALL'
                       THEN ARRAY['SELECT','INSERT','UPDATE','DELETE']
                       ELSE ARRAY[cmd] END) AS verb
      FROM pg_policies
     WHERE schemaname = 'public'
  ),
  granted AS (
    SELECT c.relname::text AS tbl, v.verb
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) AS v(verb)
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND has_table_privilege('authenticated', c.oid, v.verb)
  )
  (SELECT tbl, verb, 'granted, no policy' AS problem FROM granted
    EXCEPT
   SELECT tbl, verb, 'granted, no policy' FROM policy_verbs)
  UNION ALL
  (SELECT tbl, verb, 'policy, no grant' AS problem FROM policy_verbs
    EXCEPT
   SELECT tbl, verb, 'policy, no grant' FROM granted)
$$, 'authenticated holds exactly the verbs its RLS policies name');

-- 2. anon reaches nothing. Every policy in this schema requires a signed-in
-- identity, so any anon privilege is dead weight waiting to matter.
SELECT is_empty($$
  SELECT c.relname::text AS tbl, v.verb
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE',
                            'TRUNCATE','REFERENCES','TRIGGER']) AS v(verb)
   WHERE n.nspname = 'public'
     AND c.relkind = 'r'
     AND has_table_privilege('anon', c.oid, v.verb)
$$, 'anon holds no privilege on any table in public');

-- 3. The one RLS can never gate. TRUNCATE does not consult policies, so a
-- client role holding it can empty a table outright.
SELECT is_empty($$
  SELECT c.relname::text AS tbl, r.rolname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN (VALUES ('anon'),('authenticated'),('service_role')) AS r(rolname)
   WHERE n.nspname = 'public'
     AND c.relkind = 'r'
     AND has_table_privilege(r.rolname, c.oid, 'TRUNCATE')
$$, 'no client role holds TRUNCATE anywhere in public');

-- 4. Future tables start closed. Scoped to grantor `postgres` because that is
-- the role migrations run as, and the only one this migration can alter.
SELECT is_empty($$
  SELECT defaclrole::regrole::text AS grantor, defaclacl::text AS acl
    FROM pg_default_acl
   WHERE defaclnamespace::regnamespace::text = 'public'
     AND defaclobjtype = 'r'
     AND defaclrole = 'postgres'::regrole
     AND EXISTS (
       SELECT 1 FROM unnest(defaclacl) a
        WHERE a::text ~ '^(anon|authenticated|service_role)='
     )
$$, 'tables created by postgres grant nothing to client roles by default');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 3: Push and confirm the job fails**

```bash
git add supabase/tests/0057_table_grants_test.sql
git commit -m "test(db): assert grants and RLS policies agree"
git push -u origin feat/table-privilege-grants
gh pr create --base main --title "fix(db): explicit table privileges" --body "See docs/superpowers/specs/2026-08-12-table-privilege-grants-design.md"
gh pr checks --watch
```

Expected: `db-tests` **fails**. Read the log and confirm assertions 1, 3 and 4 are the ones failing, and that assertion 1's output names real tables. If it passes, the test has no teeth — stop and fix it before writing any migration.

```bash
gh run view --job <job-id> --log-failed | grep -A20 "0057_table_grants_test"
```

- [ ] **Step 4: Commit**

Already committed in Step 3. Do not proceed until the red is confirmed and understood.

---

### Task 2: The migration

**Files:**
- Create: `supabase/migrations/0057_table_grants.sql`

**Interfaces:**
- Consumes: the four assertions from Task 1.
- Produces: no SQL identifiers. Changes only privileges.

- [ ] **Step 1: Generate the grant matrix, do not hand-write it**

Add this temporary step to `.github/workflows/db-tests.yml`, immediately after `Start the local stack`:

```yaml
      # TEMPORARY — remove before merge.
      - name: Generate the grant matrix
        run: |
          PSQL='psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -At'
          echo '--- REVOKE lines ---'
          $PSQL -c "SELECT format('REVOKE ALL ON %I FROM anon, authenticated, service_role;', c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' ORDER BY c.relname;"
          echo '--- authenticated GRANT lines ---'
          $PSQL -c "SELECT format('GRANT %s ON %I TO authenticated;', string_agg(DISTINCT verb, ', ' ORDER BY verb), tbl) FROM (SELECT tablename::text AS tbl, unnest(CASE WHEN cmd='ALL' THEN ARRAY['SELECT','INSERT','UPDATE','DELETE'] ELSE ARRAY[cmd] END) AS verb FROM pg_policies WHERE schemaname='public') x GROUP BY tbl ORDER BY tbl;"
          echo '--- service_role GRANT lines ---'
          $PSQL -c "SELECT format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO service_role;', c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' AND c.relname <> 'mfa_recovery_codes' ORDER BY c.relname;"
```

Push, read the job log, copy the three blocks out. Then **delete the step** — it must not reach the merge.

```bash
git add .github/workflows/db-tests.yml
git commit -m "tmp: generate the grant matrix"
git push
gh run view --job <job-id> --log | grep -A40 "REVOKE lines"
```

Transcribing this by reading 57 migrations is how a wrong grant gets in. The database is the authority.

- [ ] **Step 2: Write the migration**

Create `supabase/migrations/0057_table_grants.sql`. Paste the generated blocks into the marked sections; the header and the default-privileges block are fixed text.

```sql
-- 0057_table_grants.sql
-- Until now no migration granted a table privilege to a client role. Table
-- access came from Supabase's default privileges — set by the vendor, absent
-- from this repository, pinned to no version. Supabase has since narrowed that
-- default from `arwdDxtm` to `Dxtm` for anon, authenticated and service_role,
-- so:
--
--   1. A database rebuilt from these migrations has no working client. The
--      customer app cannot read or insert an order. Disaster recovery, staging
--      and any fork are all affected.
--   2. `authenticated` holds TRUNCATE on every table, on old and new stacks
--      alike. TRUNCATE ignores row-level policies, so RLS does no work there.
--
-- The invariant, asserted generically in 0057_table_grants_test.sql: the verbs
-- a table grants `authenticated` equal the verbs its RLS policies name. A verb
-- with a policy and no grant is dead code; a grant with no policy is held back
-- by RLS alone, which is exactly how the TRUNCATE hole survived.
--
-- Revoke-then-grant rather than naming verbs to remove. `ALL` is seven
-- privileges and the leftovers are the dangerous ones — the lesson from 0056,
-- where `REVOKE INSERT, UPDATE, DELETE` would have left TRUNCATE behind.

-- === REVOKE (generated) ===
-- Paste the "REVOKE lines" block here.

-- === GRANT to authenticated (generated) ===
-- Paste the "authenticated GRANT lines" block here.

-- === GRANT to service_role (generated) ===
-- service_role bypasses RLS by design and its key never reaches a browser, so
-- its blast radius is already the whole database; excluding TRUNCATE simply
-- removes a verb nothing uses.
--
-- `mfa_recovery_codes` is deliberately absent. 0054 states the only way into
-- that table is its two SECURITY DEFINER functions, and both Edge Function call
-- sites go through them. A direct grant here would quietly falsify that.
--
-- `mfa_reset_audit` is deliberately present: reset-staff-mfa writes it with the
-- service-role client directly, not through a function.
-- Paste the "service_role GRANT lines" block here.

-- === Future tables start closed ===
-- A new table now has zero client access until its own migration says
-- otherwise. Forgetting fails loudly in the db-tests job rather than quietly in
-- production.
--
-- `FOR ROLE postgres` only. Migrations run as postgres, which is not a member
-- of supabase_admin and cannot alter its defaults — so a table created as
-- supabase_admin (for example through the dashboard) still inherits the
-- permissive default. Create tables through migrations and this holds.
--
-- ON TABLES only. The default grants `authenticated` `w` on sequences and
-- `nextval()` accepts UPDATE or USAGE, so revoking sequence defaults would
-- break inserts that rely on a sequence default, for no security gain.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated, service_role;
```

- [ ] **Step 3: Remove the temporary generator step**

```bash
git checkout origin/ci/pgtap-in-ci -- .github/workflows/db-tests.yml
```

Confirm it is gone:

```bash
grep -c "Generate the grant matrix" .github/workflows/db-tests.yml
```

Expected: `0`.

- [ ] **Step 4: Push and confirm the job passes**

```bash
git add supabase/migrations/0057_table_grants.sql .github/workflows/db-tests.yml
git commit -m "fix(db): grant table privileges explicitly, and close the defaults"
git push
gh pr checks --watch
```

Expected: `db-tests` **passes**, all four assertions green, and the six files that failed before this work (`0007_rls`, `0040_create_pickup_rpc`, `0046_customer_rls`, `0048_customer_order_edit`, `0051_carts`, `0053_customer_insert_pricing_guard`) now pass too. Those six are the reason this migration exists; if any is still red, the matrix is wrong — read assertion 1's output, it names the table and verb.

---

### Task 3: Document the new rule

**Files:**
- Modify: `docs/staff-invites.md`

**Interfaces:**
- Consumes: the behaviour established in Task 2.
- Produces: nothing.

- [ ] **Step 1: Add the paragraph**

Append to the end of `docs/staff-invites.md`:

```markdown
**Adding a table.** New tables get no client access at all — `0057` closed the
default privileges, so `anon`, `authenticated` and `service_role` start with
nothing. Grant what the table's RLS policies need, in the same migration that
creates it:

```sql
GRANT SELECT, INSERT ON widgets TO authenticated;
```

The rule the `db-tests` job enforces is that those two agree: the verbs granted
to `authenticated` must equal the verbs its policies name. Forgetting the grant
fails the job rather than the app.
```

- [ ] **Step 2: Commit**

```bash
git add docs/staff-invites.md
git commit -m "docs: new tables must grant their own privileges"
git push
```

- [ ] **Step 3: Confirm the PR is green and ready**

```bash
gh pr checks
gh pr view --json mergeable,mergeStateStatus
```

Expected: all checks pass, `mergeable=MERGEABLE`.

---

## PR sequencing

Stacking on `ci/pgtap-in-ci` means this PR *contains* #112's commit — the
`db-tests` workflow and the deletion of the dead `0015` test. That is
deliberate: the workflow and the fix that makes it pass land together, so no
knowingly-red PR ever gets merged and no migration lands without the job that
verifies it.

Merge this one and #112 is fully included; close #112 as superseded rather than
merging it separately. Merging #112 first also works, and this PR then rebases
to nothing extra — but do not merge #112 alone while it is red.

## Rollout

Production is at `0056` and fully migrated as of 2026-08-12, so this is a single
`supabase db push` of one migration once merged.

It **narrows** privileges on production, which currently holds the permissive
`arwdDxtm` defaults. Safe by construction: every verb it removes from
`authenticated` has no policy and is already refused by RLS.

**Before pushing, confirm no anon-facing path reads a table directly.** Customer
signup goes through `0042_customer_signup_rpc.sql`, a `SECURITY DEFINER`
function that executes as its owner and is unaffected — but `anon` loses its
table grants outright, so verify that is the only anon path.

**After pushing,** re-run the query that found the problem and confirm the end
state:

```sql
SELECT defaclrole::regrole, defaclacl FROM pg_default_acl
 WHERE defaclnamespace::regnamespace::text = 'public' AND defaclobjtype = 'r';
SELECT relacl FROM pg_class WHERE relname = 'orders';
```

Expected: no `anon=` or `authenticated=` entries carrying CRUD or `D` from
grantor `postgres`, and `orders` granting `authenticated` exactly
`SELECT, INSERT, UPDATE`.
