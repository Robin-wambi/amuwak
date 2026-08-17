# Design — subscription packages and per-order rate overrides

Written 2026-08-17. Two asks that share one spine: **an order's price must be
able to come from somewhere other than the global per-kg rate.** Subscriptions
are the large half; the rate override is the small half, and it turns out to be
mostly built already.

---

## Part 0 — What we already have

### The per-order rate override already exists

The staff New Pickup screen already carries a **"Custom rate (USh/kg)"** field
([new_pickup_screen.dart:900](../../../apps/amuwak_staff/lib/src/orders/new_pickup_screen.dart#L900)),
and it already does what was asked: it bills that one order at the typed rate
via `ratePerKgSnapshotUgx: customRate ?? _resolvedRate`
([:503](../../../apps/amuwak_staff/lib/src/orders/new_pickup_screen.dart#L503)),
without touching the customer's stored standing rate.

The genuine gaps are narrower:

| Gap | Evidence |
|---|---|
| A returning customer's **standing** rate can never be changed | Only set for brand-new customers ([:478](../../../apps/amuwak_staff/lib/src/orders/new_pickup_screen.dart#L478)); the customer form deliberately preserves it — *"managed from pricing"* ([customer_form_screen.dart:80](../../../apps/amuwak_staff/lib/src/customers/customer_form_screen.dart#L80)) — but the pricing screen only holds the **global** default. No screen can edit or clear it. |
| The customer app has no override path | It reads `customer.customRatePerKgUgx` and nothing else. |
| No audit, no cap | Any rider can type any rate on any order, with no reason recorded. |

### Pricing today

`PricingSettings` is a single global row: `defaultRatePerKgUgx`,
`deliveryFeeUgx`, `expressFlatUgx`, `expressPct`, `freeDeliveryThresholdUgx`.
Per-customer variation is one nullable column, `customers.custom_rate_per_kg_ugx`.
There is no per-service rate, and no concept of a plan, allowance, or prepaid
balance anywhere in Dart or SQL.

### Migration state

Repo carries `0001`–`0058`. **Next free number is `0059`.** Re-derive this
before writing any migration — this repo has a history of prefix collisions.

---

## Part 1 — The product

Nine SKUs: three tiers × three terms. Each is a **prepaid kg allowance** valid
for a fixed window, with pickup and delivery included.

| | Monthly (4wk) | Half-semester (8wk) | Full semester (16wk) |
|---|---|---|---|
| **Basic** | 14 kg — 22,000 | 28 kg — 42,000 | 56 kg — 80,000 |
| **Standard** | 20 kg + 1 blanket — 35,000 | 40 kg + 1 blanket — 65,000 | 80 kg + 2 blankets — 120,000 |
| **Premium** | 40 kg + 1 blanket — 55,000 | 80 kg + 2 blankets — 100,000 | 160 kg + 4 blankets — 180,000 |

Shorter terms are pro-rated on kg and priced at a worse per-kg rate, so a longer
commitment is always better value:

| | Monthly | Half | Full |
|---|---|---|---|
| Basic | 1,571/kg | 1,500/kg | **1,429/kg** |
| Standard | 1,750/kg | 1,625/kg | **1,500/kg** |
| Premium | 1,375/kg | 1,250/kg | **1,125/kg** |

Blanket allowances are **integers set per SKU**, not pro-rated arithmetic — a
quarter of "2 blankets" is half a blanket, which is not a thing.

> **Pricing note, not a blocker.** At full semester, Standard is 1,500/kg
> against Basic's 1,429/kg, so the "BEST VALUE" badge is carried entirely by the
> 2 included blankets (worth ~2,857 each at Basic's rate). That is a defensible
> position, but a customer who does the division will notice. Confirm it is
> deliberate.

### Decisions taken

| Question | Decision |
|---|---|
| Monthly / Half / Full | **Pro-rated allowances** — nine distinct products, not a payment schedule |
| Allowance life | **One pool per term, expires at term end.** The plan's term *is* the pool period, uniformly across all nine SKUs |
| Running out mid-term | **Bill the excess per-kg** at the customer's normal rate. Never block service |
| Blankets | **Separate integer counter** per SKU, alongside the kg pool |
| Purchase | **Staff sells and activates.** No self-serve purchase in v1 — mobile money is not built |

---

## Part 2 — Data model

Three new tables, following the snapshot discipline the order pricing already
uses.

```sql
subscription_plans          -- the catalogue: 9 rows, staff-editable
  id                 uuid pk
  tier               text     not null   -- 'basic' | 'standard' | 'premium'
  term               text     not null   -- 'monthly' | 'half_semester' | 'full_semester'
  price_ugx          integer  not null check (price_ugx > 0)
  kg_allowance       numeric  not null check (kg_allowance > 0)
  blanket_allowance  integer  not null default 0 check (blanket_allowance >= 0)
  duration_days      integer  not null check (duration_days > 0)  -- 28 / 56 / 112
  includes_delivery  boolean  not null default true
  active             boolean  not null default true
  created_at, updated_at, deleted_at
```

A table rather than a Dart enum: prices change every semester, and that must
never require a migration.

```sql
subscriptions               -- one row per purchase
  id                 uuid pk
  customer_id        uuid not null references customers(id)
  plan_id            uuid not null references subscription_plans(id)
  kg_allowance       numeric not null    -- snapshot, as sold
  blanket_allowance  integer not null    -- snapshot, as sold
  price_ugx          integer not null    -- snapshot, as sold
  includes_delivery  boolean not null    -- snapshot, as sold
  starts_at          timestamptz not null
  ends_at            timestamptz not null
  status             text not null       -- 'active' | 'expired' | 'cancelled'
  sold_by            uuid references staff(id)
  created_at, updated_at, deleted_at
  check (ends_at > starts_at)
```

Allowances are **snapshotted onto the subscription**, never read live from the
plan. Same reasoning as `ratePerKgSnapshotUgx`: reprice in January and
December's subscribers keep exactly what they bought.

```sql
subscription_usage          -- the drawdown ledger
  id               uuid pk
  subscription_id  uuid not null references subscriptions(id)
  order_id         uuid not null references orders(id)
  kg_used          numeric not null default 0 check (kg_used >= 0)
  blankets_used    integer not null default 0 check (blankets_used >= 0)
  reversed_at      timestamptz          -- set when the order is cancelled
  created_at       timestamptz not null
  UNIQUE (order_id)
```

**Why a ledger and not a counter on `subscriptions`.** The same argument the
payments research applied to `payment_amount_ugx`: a bare decrementing number
cannot survive a cancelled order, cannot show the customer where their kg went,
and double-deducts when the outbox retries. `UNIQUE (order_id)` is what makes a
retry idempotent — the second insert conflicts and does nothing, which is
exactly the failure mode that dead-lettered real orders in this repo before.

**Balance is derived, never stored:**

```
kg_remaining       = kg_allowance       − SUM(kg_used)       WHERE reversed_at IS NULL
blankets_remaining = blanket_allowance  − SUM(blankets_used) WHERE reversed_at IS NULL
```

### Changes to `orders`

```sql
ALTER TABLE orders
  ADD COLUMN subscription_id uuid REFERENCES subscriptions(id),
  ADD COLUMN covered_kg      numeric NOT NULL DEFAULT 0 CHECK (covered_kg >= 0);
```

`subscription_id` is stamped **at pickup**, not at weigh-in — see Part 4.

### Overlap constraint

```sql
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_no_overlap
  EXCLUDE USING gist (
    customer_id WITH =,
    tstzrange(starts_at, ends_at) WITH &&
  ) WHERE (status = 'active' AND deleted_at IS NULL);
```

A range-exclusion rather than a "one active row" unique index, because the
latter would also block an **early renewal** queued with a future `starts_at` —
which is a flow we want.

### Grants and RLS

Per the invariant asserted in `0057_table_grants_test.sql` — *the verbs a table
grants `authenticated` equal the verbs its RLS policies name* — each new table
must ship its grants in its own migration. Defaults now start closed, so
forgetting fails loudly in the db-tests job.

| Table | `authenticated` | Customer RLS |
|---|---|---|
| `subscription_plans` | `SELECT`, `INSERT`, `UPDATE` | read active plans (public catalogue) |
| `subscriptions` | `SELECT`, `INSERT`, `UPDATE` | read own via `auth_customer_id()` |
| `subscription_usage` | `SELECT` only | read own via `EXISTS(subscriptions)` |

Customers get **read-only** access to all three. `subscription_usage` grants no
`INSERT` to `authenticated` at all: its only writer is the SECURITY DEFINER
coverage RPC, which does not need the grant. Granting an `INSERT` with no
matching RLS policy is precisely the dead-verb shape `0057` exists to prevent.

---

## Part 3 — How an order prices against a plan

Coverage applies **at weigh-in**, against `final_weight_kg`, as a subtraction
*before* the existing `recomputeTotal` runs:

```
covered_kg  = min(final_weight_kg, kg_remaining)
billable_kg = final_weight_kg − covered_kg
total       = recomputeTotal(weight: billable_kg, …)
              with deliveryFeeUgx = 0 when the plan includes delivery
```

**Why coverage-as-subtraction rather than a separate plan-pricing path.** It
keeps `recomputeTotal` and every existing snapshot untouched, so subscriptions
do not fork the pricing engine. It also leaves the rate snapshot on the order,
which is what lets a receipt show *value* rather than a bare zero:

```
Order AMW-0421              9.0 kg
  Covered by Standard plan  3.0 kg      −4,287
  Billed                    6.0 kg  @ 1,429    8,574
  Delivery                  included by plan        0
  ─────────────────────────────────────────────────
  Due                                          8,574

  Plan balance after: 0.0 kg of 80 · 2 blankets left
```

Blankets ride the existing `pricing_catalog_items` piece-item mechanism —
coverage zeroes up to N blanket line items rather than inventing a parallel one.

### Atomicity

Weight, coverage and the ledger row are **one server-side operation**: a
SECURITY DEFINER RPC in the shape of `create_pickup` (0040). If a device could
write the weight and lose the drawdown, the balance would drift silently with no
way to attribute the loss to an order.

```
record_final_weight(p_order_id uuid, p_final_weight_kg numeric) RETURNS jsonb
  ├─ resolve the order's subscription_id (stamped at pickup)
  ├─ compute kg_remaining from the ledger
  ├─ covered_kg = min(final_weight_kg, kg_remaining)
  ├─ INSERT subscription_usage ... ON CONFLICT (order_id) DO NOTHING
  └─ UPDATE orders SET final_weight_kg, covered_kg, total_ugx
```

`ON CONFLICT (order_id) DO NOTHING` makes a queued retry safe.

### Core package

`SubscriptionPlan`, `Subscription`, `SubscriptionUsage` models plus a pure
function:

```dart
CoverageResult applyCoverage({
  required double finalWeightKg,
  required double kgRemaining,
  required int blanketsRequested,
  required int blanketsRemaining,
});
```

Unit-testable with no database, mirroring `estimateOrderTotal` and
`recomputeTotal`. The RPC is the authority; this function exists so both apps
can *display* the split without a round trip, and so the arithmetic has tests.

---

## Part 4 — Edge cases and rules

1. **Plan expiring with an order in flight.** Coverage is granted if the plan
   was active **at pickup** — the moment the rider collects and the order moves
   to `inProgress` — not at weigh-in. Otherwise a customer who books on day 111
   of a 112-day plan is punished for our turnaround time.
   `orders.subscription_id` is stamped at that transition, so the decision is
   fixed once and cannot drift as the plan ages.
2. **Overlapping plans** are forbidden by the exclusion constraint above. Early
   renewal with a future `starts_at` is permitted.
3. **Express still surcharges.** It is a speed upgrade, not weight. The UI must
   say so before the toggle is flipped.
4. **Delivery is free while a plan is active**, following the same at-pickup
   rule.
5. **Blanket overage** bills as an ordinary piece item from the catalogue.
6. **Refunds are out of scope for v1.** Cancelling sets `status = 'cancelled'`;
   money is settled as cash with a note. Explicitly not half-built — a partial
   refund path without a payments ledger would be worse than none.
7. **Expiry warnings** at 14 and 3 days remaining: *"You have 22 kg left,
   expiring 22 Dec."* Fair to the customer and the best available re-order
   prompt.
8. **Offline** shows last-known balance, labelled as such. Coverage is always
   computed server-side, so a stale local balance can never overdraw.
9. **Status transitions.** `active → expired` is time-driven; compute it on read
   (`ends_at < now()`) rather than relying on a scheduled job, so a missed cron
   cannot leave a dead plan spending kg.

---

## Part 5 — Where it surfaces

### Staff app

| Screen | Change |
|---|---|
| Pricing / Settings | New **Subscription plans** screen: the nine SKUs, price / kg / blankets / duration editable, active toggle. Manager-only. |
| Customer detail | **Subscription card.** No plan → `[Start subscription]` sheet (tier + term, start date, amount paid + method, Activate). Active plan → balance, blankets, expiry with days left, `[Cancel plan]`. |
| New Pickup | Banner when the matched customer has an active plan: *"Standard · 62.5 kg left · expires 22 Dec"*. Order auto-links. The custom-rate field stays — it now prices the overage. |
| Weigh-in | Live split as the weight is typed: *"9.0 kg → 3.0 covered, 6.0 billable @ 1,429 = 8,574"*. |

Selling is **manager-only** in v1: real money, no payment rails, and widening
the role later is a one-line change.

### Customer app

- **Home** — replace the two static promise cards with a **balance card** for
  subscribers: plan, kg remaining with a progress bar, blankets, expiry
  countdown. Best real estate in the app, answering the question they have.
- **Order detail** — the coverage split above, plus balance after this order.
- **Payments tab** — a plan section above Total Due showing cumulative savings.
  Turns a bill screen into a value screen.
- **Subscribe entry point** — explains the nine SKUs, then *"call us"* with the
  MTN and Airtel numbers from the flyer. Captures demand without payment rails
  and matches how the packages are already being advertised.

---

## Part 6 — The companion rate-override fix

Small, independent, and shippable first.

1. **Make the standing rate editable.** Add `custom_rate_per_kg_ugx` to the
   customer form, manager-only, with a clear-to-default action. Today it is
   write-once at customer creation and unreachable forever after.
2. **Reason + audit on the per-order override.** When New Pickup's custom rate
   differs from the resolved rate, require a short reason and write an audit row
   (`rate_override_audit`: order id, actor, from, to, reason, timestamp).
3. **Guard rail.** A rate below a configurable floor (e.g. 60% of default)
   requires a manager. Any rider being able to set any price on any order is a
   revenue leak that subscriptions will only widen.

---

## Part 7 — Suggested sequencing

Each milestone leaves the repo green and is independently shippable. This spec
is deliberately larger than one implementation plan: **S0 is its own plan**
(it shares no code with the rest), **S1–S4 are the subscription plan proper**,
and **S5 is blocked** until a notification channel exists and should not be
planned yet.

**S0 — Rate override fix.** Editable standing rate, reason + audit, floor guard.
No new tables beyond the audit row. *Independent of everything below.*

**S1 — Schema + core.** Migration `0059`: three tables, `orders` columns,
exclusion constraint, grants, RLS. `amuwak_core` models plus `applyCoverage()`
and its tests. Drift mirrors in both apps. *No UI. Unblocks everything else.*

**S2 — Sell and activate.** Staff plan-catalogue screen and the customer-detail
subscription card. Plans can be sold; nothing consumes them yet.

**S3 — Coverage at weigh-in.** The `record_final_weight` RPC, the New Pickup
banner, and the live split on the weigh-in screen. *This is the milestone that
makes subscriptions real.*

**S4 — Customer visibility.** Balance card on Home, coverage split on order
detail, plan section in Payments, subscribe entry point.

**S5 — Expiry warnings.** 14-day and 3-day notices. Depends on whichever
notification channel ships first (see the customer-app research on WhatsApp
versus push).

---

## Open questions

1. **Is the Standard "BEST VALUE" badge deliberate**, given it is 1,500/kg
   against Basic's 1,429/kg at full semester?
2. **Confirm the blanket allowances** for shorter terms. This spec assumes
   Standard 1/1/2 and Premium 1/2/4 for monthly/half/full. Basic has none.
3. **Do semester dates come from a calendar** (fixed university term dates) or
   is `starts_at` simply the sale date + `duration_days`? This spec assumes the
   latter; a fixed academic calendar would change how `ends_at` is computed and
   how mid-semester sales are priced.
4. **Can a customer hold a plan and still place orders that bypass it?** This
   spec assumes no — an active plan always covers first. If a student wants to
   save kg for finals week, that would need an opt-out per order.
5. **What happens on renewal with kg left?** This spec expires them. A carry-over
   option was considered and rejected for v1 as an unbounded liability, but it
   is the strongest retention lever available if you want it later.
