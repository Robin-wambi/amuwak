# Staff App: Dashboard, Expenses & Customers UI Redesign

## Context

The staff app's Home tab, Expenses tab, and Customers tab have accumulated some
rough edges the user wants cleaned up before they're comfortable calling this
"professional":

- **Business at a glance** currently shows exactly 2 tiles (today's revenue,
  new customers) — the ask is to keep those 2 as the headline, and move the 5
  order-count cards that sit directly below (Assigned/Pending
  pickup/In progress/Ready for delivery/Completed today) behind a "View
  all / Less" toggle at the right of the section's title row, collapsed by
  default.
- **The greeting card**: "Good morning, Robin" and the "Manager" role chip
  currently sit inside the orange gradient card, side by side. The ask is to
  pull both outside the card — greeting on the left, role chip on the right,
  balancing each other in a row above the card — leaving just the
  avatar + status line inside the gradient surface.
- **Expenses tab** looks unpolished: bare `ListTile` rows with no date/time,
  a plain "Total spent" card with no breakdown, no search or filtering. It
  needs to be brought up to the visual bar the Orders tab already sets
  (card-based rows, richer summary, search/filter chips).
- **Customers tab** is similarly behind: plain `ListTile` + `CircleAvatar`
  rows, not using the app's `AppCard` component, and not surfacing data that
  already exists on the model (standing rate override, notes).

Research on 2026 mobile UI best practices ([UXPin dashboard guide](https://www.uxpin.com/studio/blog/dashboard-design-principles/),
[Querio mobile dashboards](https://querio.ai/articles/how-to-design-dashboards-for-mobile-users),
expense-tracker and CRM contact-list UX roundups) confirms the direction:
limit headline metrics to a handful with the rest behind progressive
disclosure, prefer scannable cards over dense list tiles, and surface
category breakdowns rather than a bare total.

Scope for this pass, confirmed with the user:
- Business-at-a-glance toggle: **collapsed by default** (matches "today's
  revenue and new customers only" literally); this requires updating 7
  existing Home-tab tests that currently interact with the order-count cards
  directly.
- Customers: **visual polish only** — restyle rows as cards, surface
  standing-rate/notes affordances that already exist on the model. No new
  read-only detail screen; tapping a row keeps opening the existing edit
  form.
- Expenses: **cards + category breakdown + search/filter, no chart** — reuses
  existing aggregation helpers, no new chart component.

All four workstreams reuse existing design tokens/components — `AppCard`,
`AppColors`, `AppSpacing`, `AppRadii`, `formatUgx` (all in
`packages/amuwak_core/lib/src/shared/theme/`) — and existing patterns already
proven elsewhere in the app (`OrderCard`, the Orders tab's search + FilterChip
row, `daily_report_screen.dart`'s metric-strip/breakdown-card shapes, and the
expand/collapse toggle already used in `new_pickup_screen.dart`). No new
backend/data plumbing is needed anywhere in this plan.

This repo executes plans task-by-task with TDD and one commit per task (see
`docs/superpowers/plans/` convention). Each task below is independently
committable.

---

## Workstream A — Business at a glance toggle

### Task 1 (Workstream A): Collapse order-count metrics behind a View all/Less toggle

**Files:**
- `apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart`
- `apps/amuwak_staff/test/dashboard/staff_dashboard_screen_test.dart`

**Changes:**
- `_BusinessAtAGlance` (currently `staff_dashboard_screen.dart:1635`, a
  `ConsumerWidget`) becomes a `ConsumerStatefulWidget` holding
  `bool _expanded = false`. It gains a required
  `onOpenFiltered: void Function(OrderFilter)` param, forwarded from
  `_HomeTab` (which already holds this exact callback at `_HomeTab:980` —
  just thread it through).
- The title row becomes
  `Row([Text('Business at a glance'), Spacer(), _toggle])` where `_toggle` is
  a small `key: const Key('glance_toggle')` control — icon
  `Icons.expand_more` / `Icons.expand_less`, label `'View all'` / `'Less'`,
  `AppColors.primary` — the same idiom as the `_optionalExpanded` toggle in
  `new_pickup_screen.dart` (~line 935), just inline instead of full-width.
- After the existing revenue/new-customers `Row` (unchanged), add: when
  expanded, `SizedBox(height: AppSpacing.xl)` + the *existing*
  `_SummaryGrid(orders: orders, onCardTap: onOpenFiltered)` class
  (`staff_dashboard_screen.dart:1514`) — relocated into this widget, not
  duplicated.
- `_HomeTab.build()` (`staff_dashboard_screen.dart:989-1031`): remove the
  separate `middle` variable's loaded-state branch (`_SummaryGrid(...)`).
  New shape: while `loading`, keep rendering the `LinearProgressIndicator` in
  that slot; once loaded, `_BusinessAtAGlance` alone renders (it now owns the
  grid internally, gated by its own toggle) — delete the standalone
  `reveal(middle)` step for the loaded case.
- **Existing test updates** — search `staff_dashboard_screen_test.dart` for
  direct interactions with `find.text('Assigned')`,
  `find.text('Pending pickup')`, `find.text('Completed today')` on the Home
  tab (not the Orders tab's `FilterChip`s, whose labels are formatted
  `'Assigned (3)'` and never collide). In each of the 7 affected tests, add
  `await tester.tap(find.byKey(const Key('glance_toggle'))); await tester.pump();`
  before the interaction. For the loading→data transition test, swap its
  post-data `find.text('Assigned')` assertion for
  `find.text('Business at a glance')` as the "data has arrived" signal.
- **New tests**: grid is `findsNothing` by default and `findsOneWidget` after
  tapping the toggle (back to `findsNothing` on a second tap), toggle label
  flips `'View all'` ↔ `'Less'`; `glance_revenue`/`glance_new_customers`
  tiles stay visible in both toggle states.

**Commit:** `feat(dashboard): collapse order-count metrics behind a View all/Less toggle`

---

## Workstream B — Greeting card / role chip relocation

### Task 2 (Workstream B): Move greeting + role chip outside the gradient header; restyle the chip

**Files:**
- `apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart`
- `apps/amuwak_staff/test/dashboard/staff_dashboard_screen_test.dart`

**Changes:**
- `_DashboardHeader.build()` (`staff_dashboard_screen.dart:1412-1484`):
  restructure from
  `AnimatedGradientHeader(child: Row(avatar, Column(Row(greeting, chip), status)))`
  to a top-level `Column`:
  1. `Row([Expanded(Text(greetingLine, style: textTheme.headlineMedium)), if (role != null) ...[SizedBox(width: AppSpacing.sm), _RoleChip(label: role)]])`
     — drop the `.copyWith(color: AppColors.white)` override on the greeting
     text so it inherits the theme's default `headlineMedium` color
     (`AppColors.dark`, confirmed in
     `packages/amuwak_core/lib/src/shared/theme/app_typography.dart`), which
     reads correctly on the scaffold background.
  2. `SizedBox(height: AppSpacing.md)`.
  3. `AnimatedGradientHeader(child: Row([CircleAvatar(...unchanged...), SizedBox(width: AppSpacing.lg), Expanded(Text(secondLine, ...))]))`
     — the brand-mark avatar and status line are all that remain inside the
     gradient card.
- `_RoleChip` (`staff_dashboard_screen.dart:1487-1509`) restyle: white
  background, `Border.all(color: AppColors.cardBorder)`, text
  `color: AppColors.primary`, radius switched to the `AppRadii.chip` token —
  reads as a small bordered pill on the plain background instead of a
  translucent-on-orange pill.
- **New tests**: the greeting text is no longer a descendant of
  `AnimatedGradientHeader` (`find.descendant(of: find.byType(AnimatedGradientHeader), matching: find.textContaining('Good '))`
  is `findsNothing`, while the greeting itself is `findsOneWidget` elsewhere);
  same check for the role-chip label; the status line remains a descendant of
  `AnimatedGradientHeader`.
- No existing tests reference `_RoleChip`'s position or the header's internal
  structure (the one `find.text('Manager')` in the suite belongs to the
  unrelated Account-tab role row), so no other test changes expected —
  confirm by running the full file after the change.

**Commit:** `feat(dashboard): move greeting + role chip outside the gradient header card`

---

## Workstream C — Expenses tab

### Task 3 (Workstream C): Reskin expense rows as AppCard-based cards

**Files:**
- `apps/amuwak_staff/lib/src/expenses/expenses_list_screen.dart`
- `apps/amuwak_staff/test/expenses/expenses_list_screen_test.dart`

**Changes:**
- Add a private `IconData _categoryIcon(ExpenseCategory c)` switch in
  `expenses_list_screen.dart` (keep `ExpenseCategory` itself free of Flutter
  imports, matching how icons are chosen inline at call sites elsewhere in
  the app).
- `_ExpenseRow` (`expenses_list_screen.dart:163-192`): replace the bare
  `ListTile` with an `AppCard`-wrapped `Row` — leading 44×44
  primary-tinted icon tile (same shape as `OrderCard`'s icon avatar), title =
  `category.label`, subtitle = note (unchanged, only if non-empty), trailing
  = amount (emphasized) + optional delete `IconButton` (**keep the existing
  key** `Key('expense_delete_${expense.id}')` so no test churn there).
- Existing tests assert on text content, not `ListTile` structure, so they
  should keep passing — verify by running the file rather than assuming. Add
  one new test asserting rows render inside `AppCard`.

**Commit:** `feat(expenses): reskin ledger rows as AppCard-based cards`

### Task 4 (Workstream C): Richer summary card with per-category breakdown

**Files:**
- `apps/amuwak_staff/lib/src/expenses/expenses_list_screen.dart`
- `apps/amuwak_staff/test/expenses/expenses_list_screen_test.dart`

**Changes:**
- Replace `_TotalCard` (`expenses_list_screen.dart:135-161`, a bare `Card`)
  with a new `_ExpensesSummaryCard`: an `AppCard` containing a row per
  present `ExpenseCategory` (icon + label + amount, iterated in
  `ExpenseCategory.values` order, skipping absent categories — the same
  shape as `daily_report_screen.dart`'s `_ExpensesCard` minus its
  net-profit/margin section, which needs revenue data this tab doesn't have),
  a `Divider`, then an emphasized "Total spent" row. Reuse
  `ExpenseListStats.byCategory` / `totalExpenseUgx` from
  `expense_list_extensions.dart` — no new aggregation logic needed.
- **Regression to fix while touching this**: the existing test
  `'renders the total spent across all expenses'` seeds two expenses sharing
  the same default category (`detergent`), both totaling `USh 10,000`. Once
  a per-category breakdown row exists, `find.text('USh 10,000')` goes from
  `findsOneWidget` to `findsNWidgets(2)`. Update the fixture to use two
  different categories so per-category and total amounts are
  distinguishable.
- **New test**: seed expenses across 2+ categories with distinct amounts,
  assert each category label + its formatted amount render, plus the
  combined total.

**Commit:** `feat(expenses): show a per-category breakdown in the summary card`

### Task 5 (Workstream C): Search + category filter chips

**Files:**
- `apps/amuwak_staff/lib/src/expenses/expenses_list_screen.dart`
- `apps/amuwak_staff/test/expenses/expenses_list_screen_test.dart`

**Changes:**
- `ExpensesListView` (currently a `StatelessWidget`) becomes a
  `StatefulWidget`, mirroring `CustomersListView` / the Orders tab's
  `_OrdersBody`: add a `TextField` (`Key('expenses_search')`) matching note
  text and/or category label above the list, and a horizontal `FilterChip`
  row (`'All'` + each `ExpenseCategory`, `Key('expenses_chip_<category>')`) —
  same layout as `_OrdersBody` (`staff_dashboard_screen.dart:~1092-1129`).
- The summary card (`_ExpensesSummaryCard`) always aggregates the **full,
  unfiltered** list; only the day-grouped row list below narrows by
  query/category — mirrors how the Orders tab keeps its counts stable while
  filtering, so "Total spent" doesn't appear to change mid-search.
- **New tests**: search narrows to matching notes; a category chip narrows to
  that category and updates the visible row set; `'All'` resets; the summary
  card's total is unaffected by an active filter.

**Commit:** `feat(expenses): add search and category filter chips`

---

## Workstream D — Customers tab

### Task 6 (Workstream D): Reskin customer rows as AppCard-based cards

**Files:**
- `apps/amuwak_staff/lib/src/customers/customers_list_screen.dart`
- `apps/amuwak_staff/test/customers/customers_list_screen_test.dart`

**Changes:**
- Row (`customers_list_screen.dart:116-125`): replace the bare `ListTile`
  with `AppCard(onTap: ...)` wrapping a `Row`: leading `CircleAvatar` (kept
  for at-a-glance scanning, re-tinted to `AppColors.primary`-on-white instead
  of the Material default), name + phone/address as today, plus:
  - a standing-rate chip (`'USh ${formatUgx(c.customRatePerKgUgx!.round())}/kg'`)
    shown only when `customRatePerKgUgx != null` — mirrors the rounding
    already done in `customer_form_screen.dart`;
  - a small "has notes" indicator icon (`Icons.sticky_note_2_outlined`) shown
    only when `notes` is non-empty/non-whitespace (icon only, no note text —
    progressive disclosure, per the CRM UX research).
- Existing tests assert `find.text(name)` / `find.text(phone)` and the
  `onCustomerTap` callback — unaffected by the re-skin, should keep passing
  as-is; verify by running the file.
- **New tests**: standing-rate chip shown/hidden correctly; notes indicator
  shown/hidden correctly.

**Commit:** `feat(customers): reskin rows as AppCard-based cards with rate/notes affordances`

---

## Sequencing notes

- Task 1 (A) and Task 2 (B) both touch `staff_dashboard_screen.dart` but
  disjoint line ranges (`_BusinessAtAGlance`/`_HomeTab` vs.
  `_DashboardHeader`/`_RoleChip`) — low conflict risk done as separate
  sequential commits.
- Tasks 3-5 (C) and Task 6 (D) are in fully separate files/tests from
  Tasks 1-2 (A/B) and each other.
- Recommended order: Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6.

## Verification

- Run each touched test file individually (per this repo's convention on
  this host — `flutter test <path>`, one file at a time, not the whole suite
  at once; use `--timeout=none` if a file is slow to load).
- `flutter analyze` clean on all touched files.
- Manually re-check: the Task 4 total/breakdown string-collision fix, and
  the 7 Task 1 test updates — these are the two spots most likely to have a
  subtle miss.
- After all tasks land, run the app (`flutter run`) and manually check the
  Home tab (toggle expand/collapse, greeting/chip layout on a narrow phone
  width), Expenses tab (cards, summary breakdown, search/filter), and
  Customers tab (cards, rate/notes chips) — this is a visual redesign, so
  automated tests alone don't confirm it looks right.

### Critical files
- `apps/amuwak_staff/lib/src/dashboard/staff_dashboard_screen.dart`
- `apps/amuwak_staff/test/dashboard/staff_dashboard_screen_test.dart`
- `apps/amuwak_staff/lib/src/expenses/expenses_list_screen.dart`
- `apps/amuwak_staff/test/expenses/expenses_list_screen_test.dart`
- `apps/amuwak_staff/lib/src/expenses/expense_list_extensions.dart`
- `apps/amuwak_staff/lib/src/customers/customers_list_screen.dart`
- `apps/amuwak_staff/test/customers/customers_list_screen_test.dart`
