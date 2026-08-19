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
| **Standard** | 20 kg — 35,000 | 40 kg + 1 blanket — 65,000 | 80 kg + 2 blankets — 120,000 |
| **Premium** | 40 kg + 1 blanket — 55,000 | 80 kg + 2 blankets — 100,000 | 160 kg + 4 blankets — 180,000 |

Shorter terms are pro-rated on kg and priced at a worse per-kg rate, so a longer
commitment is always better value:

| | Monthly | Half | Full |
|---|---|---|---|
| Basic | 1,571/kg | 1,500/kg | **1,429/kg** |
| Standard | 1,750/kg | 1,625/kg | **1,500/kg** |
| Premium | 1,375/kg | 1,250/kg | **1,125/kg** |

Blankets are a **cadence**, not a lump: Standard washes one blanket every 8
weeks, Premium one every 4. The flyer's headline figures are that cadence over a
16-week semester, and the shorter terms fall out of the same rule:

| Tier — cadence | Monthly (4wk) | Half (8wk) | Full (16wk) |
|---|---|---|---|
| Basic — none | 0 | 0 | 0 |
| Standard — 1 per 8wk | **0** | 1 | 2 |
| Premium — 1 per 4wk | 1 | 2 | 4 |

Standard's monthly plan resolves to **zero** rather than rounding 0.5 up, so the
cadence holds exactly at every SKU and no tier leaks a part-blanket. Its
marketing copy must therefore not promise blankets on the monthly term.

Once resolved, a blanket allowance behaves **exactly like the kg pool** — one
pool for the term, spent whenever, expiring with the term. There is no monthly
metering, so there is no second expiry rule to build or explain.

Kg allowances and prices are set **per SKU**, not derived from a formula. The
per-kg figures above are consequences of the printed prices, not inputs to them,
so a tier being dearer per kg than the one below it is a deliberate pricing
choice rather than an error to correct.

### Decisions taken

| Question | Decision |
|---|---|
| Monthly / Half / Full | **Pro-rated allowances** — nine distinct products, not a payment schedule |
| Allowance life | **One pool per term, expires at term end.** The plan's term *is* the pool period, uniformly across all nine SKUs |
| Running out mid-term | **Bill the excess per-kg at the plan's own rate**, not the global default. Never block service |
| Blankets | **Separate integer counter**, derived from a per-tier cadence (Standard 1 per 8wk, Premium 1 per 4wk), then pooled for the term exactly like kg |
| Purchase | **Staff sells and activates.** No self-serve purchase in v1 — mobile money is not built |
| Term dates | `starts_at` defaults to the sale date and `ends_at` to `starts_at + duration_days`, but **a manager can override both** at activation |
| Using the plan | **Opt-out per order.** An active plan covers by default; the customer or staff can decline it on a given order to bank kg for later |

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
  overage_rate_per_kg_ugx  integer not null check (overage_rate_per_kg_ugx > 0)
  includes_delivery  boolean  not null default true
  active             boolean  not null default true
  created_at, updated_at, deleted_at
```

A table rather than a Dart enum: prices change every semester, and that must
never require a migration.

`overage_rate_per_kg_ugx` is stored explicitly rather than computed as
`price_ugx / kg_allowance`. It seeds to that value — 1,429 for Basic full, 1,125
for Premium full, and so on down the per-kg table above — but keeping it as its
own column means overage can later be priced at a premium, or held flat across
terms, without a migration. It also removes any float division from the billing
path, which matters because UGX has no minor units.

```sql
subscriptions               -- one row per purchase
  id                 uuid pk
  customer_id        uuid not null references customers(id)
  plan_id            uuid not null references subscription_plans(id)
  kg_allowance       numeric not null    -- snapshot, as sold
  blanket_allowance  integer not null    -- snapshot, as sold
  price_ugx          integer not null    -- snapshot, as sold
  overage_rate_per_kg_ugx integer not null -- snapshot, as sold
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

`starts_at` and `ends_at` are stored, not computed on read. They default to the
sale date and `starts_at + duration_days`, but a manager can set either at
activation — so a student buying two weeks into term can be given a window that
matches the term rather than their purchase date. Because they are stored, a
later change to the plan's `duration_days` never moves an existing subscriber's
expiry.

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

`subscription_id` is stamped **at pickup**, not at weigh-in — see Part 4. NULL
carries both meanings that price identically: the customer has no plan, or they
had one and opted out of it for this order. Nothing else needs to distinguish
them, so nothing stores the difference.

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
rate        = subscription_id IS NULL
                ? (customer.custom_rate ?? settings.default_rate)   -- unchanged
                : subscription.overage_rate_per_kg_ugx              -- the plan's own
covered_kg  = min(final_weight_kg, kg_remaining)
billable_kg = final_weight_kg − covered_kg
total       = recomputeTotal(weight: billable_kg, rate: rate, …)
              with deliveryFeeUgx = 0 when the plan includes delivery
```

The rate is the **plan's own** for a plan-linked order, so a Premium subscriber
who crosses their allowance keeps paying 1,125/kg rather than jumping to the
global default. An order with no plan — including one where the customer opted
out — resolves its rate exactly as it does today.

That rate still lands in the order's existing `rate_per_kg_snapshot_ugx`. No new
concept: the order simply records which rate it was billed at, as it always has.

**Why coverage-as-subtraction rather than a separate plan-pricing path.** It
keeps `recomputeTotal` and every existing snapshot untouched, so subscriptions
do not fork the pricing engine. It also leaves the rate snapshot on the order,
which is what lets a receipt show *value* rather than a bare zero:

```
Order AMW-0421              9.0 kg      Standard · Full Semester
  Covered by plan           3.0 kg      −4,500
  Billed                    6.0 kg  @ 1,500    9,000
  Delivery                  included by plan        0
  ─────────────────────────────────────────────────
  Due                                          9,000

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
  required int overageRatePerKgUgx,
});
// → coveredKg, billableKg, overageUgx, coveredBlankets, billableBlankets
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
2. **Opting out of the plan on one order.** An active plan covers by default, but
   either the customer or the rider can decline it per order — a student banking
   kg for finals week is the motivating case. Declining leaves
   `orders.subscription_id` NULL, so the order prices as an ordinary per-kg job
   and no ledger row is ever written. The choice is made **at pickup**, alongside
   the stamping in rule 1, and cannot be changed afterwards: once the laundry has
   been weighed and billed, flipping it would silently move money.
3. **Overlapping plans** are forbidden by the exclusion constraint above. Early
   renewal with a future `starts_at` is permitted.
4. **Express still surcharges.** It is a speed upgrade, not weight. The UI must
   say so before the toggle is flipped.
5. **Delivery is free while a plan is active**, following the same at-pickup
   rule — and it survives a per-order opt-out, because delivery is a benefit of
   *holding* a plan rather than something drawn from the allowance. See "Still
   open" below: the opposite rule is defensible and this one is a choice.
6. **Blanket overage** bills as an ordinary piece item from the catalogue.
7. **Refunds are out of scope for v1.** Cancelling sets `status = 'cancelled'`;
   money is settled as cash with a note. Explicitly not half-built — a partial
   refund path without a payments ledger would be worse than none.
8. **Expiry warnings** at 14 and 3 days remaining: *"You have 22 kg left,
   expiring 22 Dec."* Fair to the customer and the best available re-order
   prompt.
9. **Offline** shows last-known balance, labelled as such. Coverage is always
   computed server-side, so a stale local balance can never overdraw.
10. **Status transitions.** `active → expired` is time-driven; compute it on read
    (`ends_at < now()`) rather than relying on a scheduled job, so a missed cron
    cannot leave a dead plan spending kg.

---

## Part 5 — Where it surfaces

### Staff app

| Screen | Change |
|---|---|
| Pricing / Settings | New **Subscription plans** screen: the nine SKUs, price / kg / blankets / duration editable, active toggle. Manager-only. |
| Customer detail | **Subscription card.** No plan → `[Start subscription]` sheet (tier + term, **start and end dates both editable** and pre-filled from `duration_days`, amount paid + method, Activate). Active plan → balance, blankets, expiry with days left, `[Cancel plan]`. |
| New Pickup | Banner when the matched customer has an active plan: *"Standard · 62.5 kg left · expires 22 Dec"*, plus a **"Use subscription" toggle, on by default**. Turning it off leaves the order unlinked and prices it as an ordinary per-kg job. The custom-rate field stays and is what an unlinked order bills at. |
| Weigh-in | Live split as the weight is typed: *"9.0 kg → 3.0 covered, 6.0 billable @ 1,500 = 9,000"*, at the plan's own overage rate. |

Selling is **manager-only** in v1: real money, no payment rails, and widening
the role later is a one-line change.

### Customer app

- **Home** — replace the two static promise cards with a **balance card** for
  subscribers: plan, kg remaining with a progress bar, blankets, expiry
  countdown. Best real estate in the app, answering the question they have.
- **Place order / cart checkout** — a **"Use my subscription" toggle, on by
  default**, mirroring New Pickup. This is the customer-side opt-out: a student
  banking kg for finals week turns it off and pays cash for that one order. It
  must show what the choice costs — *"Using your plan · covers ~6 kg"* against
  *"Paying separately · about 9,000"* — so the decision is informed rather than a
  bare switch.
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

## Resolved — answers from review

| Question | Answer | Where it landed |
|---|---|---|
| Is Standard being dearer per kg than Basic deliberate? | Yes. Every package carries its own values; they are not derived from a default | Part 1, and the reason `overage_rate_per_kg_ugx` is a stored column |
| Blanket allowances on shorter terms | A **cadence**: Standard 1 per 8 weeks, Premium 1 per 4. Resolved per term, Standard monthly to zero | Part 1 blanket table |
| Are blankets pooled or metered monthly? | **Pooled for the term**, exactly like kg | Part 1 |
| Where do term dates come from? | Sale date + `duration_days`, **both overridable by a manager** | Part 2 `subscriptions`, Part 5 activation sheet |
| Can a customer bypass the plan on one order? | **Yes** — per-order opt-out, on both staff and customer sides | Part 4 rule 2, Part 5 both apps |
| Renewal with kg left | No carry-over. Exhausted allowance means paying per kg for extra | Part 1 decisions, Part 3 |
| Which rate does overage bill at? | **The plan's own** per-kg rate, not the global default | Part 2 `overage_rate_per_kg_ugx`, Part 3 |

## Still open

1. **The printed flyer will mislead monthly Standard buyers.** It advertises
   Standard as "+ 2 blankets" with no term qualifier, but the cadence resolves
   that SKU to zero. Either qualify the copy, or accept a rounded-up blanket on
   monthly Standard and change `blanket_allowance` to 1. This is a marketing
   decision with a one-row data consequence — it does not block S1.
2. **Does a plan-holder who opts out of coverage still get free delivery?** This
   spec says **yes**: delivery is a benefit of holding an active plan, not a
   consumable drawn from the allowance, so opting out of kg coverage on one order
   does not forfeit it. Flagged rather than buried because it is a revenue
   decision, and the opposite rule is equally defensible.
3. **Who may sell a plan?** Assumed manager-only for v1. If riders are expected
   to sell on campus, say so before S2 — it changes the RLS policy, not the
   schema.
