import 'dart:math' as math;

import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

import '../expenses/expense.dart';
import '../expenses/expense_list_extensions.dart';
import '../orders/order.dart';
import '../orders/order_filter.dart';
import '../orders/order_list_extensions.dart';
import 'report_period.dart';

class DailyReportScreen extends StatelessWidget {
  const DailyReportScreen({
    super.key,
    required this.orders,
    this.expenses = const [],
  });

  final List<LaundryOrder> orders;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text(
          'Daily report',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: DailyReportView(orders: orders, expenses: expenses),
    );
  }
}

class DailyReportView extends StatefulWidget {
  const DailyReportView({
    super.key,
    required this.orders,
    this.expenses = const [],
    this.onOpenFiltered,
    this.onOpenItems,
    this.onAddExpense,
    this.onOpenExpenses,
    this.initialPeriod = ReportPeriod.daily,
    this.now,
  });

  final List<LaundryOrder> orders;

  /// Recorded expenses, netted against earned revenue within the selected
  /// period. Defaults to empty so the standalone/test render path stays valid.
  final List<Expense> expenses;

  /// Opens the read-only list behind a tappable metric card. Null in the
  /// standalone/test render path, which leaves the cards inert.
  final void Function(OrderFilter filter, {String? title})? onOpenFiltered;

  /// Opens the items breakdown page behind the "Items" card.
  final VoidCallback? onOpenItems;

  /// Opens the "record an expense" form. When non-null the Expenses card always
  /// renders (with an Add action) even before any expense is logged.
  final VoidCallback? onAddExpense;

  /// Opens the full expenses list (tap target on the Expenses card). Optional.
  final VoidCallback? onOpenExpenses;

  /// The period the report opens on. Defaults to [ReportPeriod.daily].
  final ReportPeriod initialPeriod;

  /// Injectable clock for the current-period window. Defaults to the wall clock;
  /// tests pass a fixed value so the window is deterministic.
  final DateTime Function()? now;

  @override
  State<DailyReportView> createState() => _DailyReportViewState();
}

class _DailyReportViewState extends State<DailyReportView> {
  late ReportPeriod _period = widget.initialPeriod;

  @override
  Widget build(BuildContext context) {
    // Scope both orders and expenses to the selected period's window so every
    // figure below — money, spend, profit, counts, status — covers the same span.
    final now = (widget.now ?? DateTime.now)();
    final window = _period.currentWindow(now);
    final orders = widget.orders.inPeriod(window);
    final expenses = widget.expenses.inPeriod(window);
    // The monthly revenue tracker is deliberately period-INDEPENDENT: unlike
    // every other figure on this screen (scoped to `window`), it always spans
    // the current calendar month, so it reads from the unscoped `widget.orders`
    // rather than the period-scoped `orders`.
    final monthlyRevenue = _MonthlyRevenueSeries.fromOrders(
      widget.orders,
      now: now,
    );
    // The adjacent prior window powers the period-over-period trend chips. Past
    // orders use inPastPeriod (excludes immediate "now" orders) so they don't
    // leak into the comparison.
    final prevWindow = _period.previousWindow(now);
    final prevOrders = widget.orders.inPastPeriod(prevWindow);
    final onOpenFiltered = widget.onOpenFiltered;
    final onOpenItems = widget.onOpenItems;
    final onAddExpense = widget.onAddExpense;
    final onOpenExpenses = widget.onOpenExpenses;

    final totalOrders = orders.length;
    final pendingPickup = orders.countByStatus(OrderStatus.pendingPickup);
    final inProgress = orders.countByStatus(OrderStatus.inProgress);
    final readyForDelivery = orders.countByStatus(OrderStatus.readyForDelivery);
    // Derive the two tappable cards' counts from the exact OrderFilter each
    // card opens, so a card's number can never disagree with the list behind it
    // (vs. re-deriving completed via countByStatus and pendingWork via the
    // `totalOrders - completed` arithmetic, which are separate code paths).
    final completed = OrderFilter.completed.count(orders);
    final pendingWork = OrderFilter.pendingWork.count(orders);
    final totalItems = orders.totalItems;

    // Cash-first money view: collected (in hand), outstanding (receivables),
    // billed (total charged). In normal operation billed == collected +
    // outstanding; they diverge only when an order was over-collected. Each
    // figure carries its previous-period value for the trend chip.
    final collected = orders.collectedUgx;
    final outstanding = orders.outstandingUgx;
    final billed = orders.billedUgx;
    final prevCollected = prevOrders.collectedUgx;
    final prevOutstanding = prevOrders.outstandingUgx;
    final prevBilled = prevOrders.billedUgx;

    final breakdown = orders.revenueBreakdown;
    final avgOrderValue = orders.avgOrderValueUgx;
    final prevAvgOrderValue = prevOrders.avgOrderValueUgx;
    final provisionalRevenue = orders.provisionalRevenueUgx;
    final finalRevenue = orders.finalRevenueUgx;

    final totalExpenses = expenses.totalExpenseUgx;
    final expensesByCategory = expenses.byCategory;
    // Net PROFIT = cash collected minus spend (not earned/booked) — only money
    // actually in hand counts. Margin is profit as a % of collected.
    final netProfit = collected - totalExpenses;
    final marginPct =
        collected == 0 ? 0 : (netProfit / collected * 100).round();
    // Show the Expenses section once there's something to show or a way to add:
    // keeps the standalone/test render path (no expenses, no callback) unchanged.
    final showExpenses = expenses.isNotEmpty || onAddExpense != null;

    VoidCallback? openFilter(OrderFilter filter, String title) =>
        onOpenFiltered == null ? null : () => onOpenFiltered(filter, title: title);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          SegmentedButton<ReportPeriod>(
            segments: [
              for (final p in ReportPeriod.values)
                ButtonSegment<ReportPeriod>(value: p, label: Text(p.label)),
            ],
            selected: {_period},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _period = selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.white,
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg - 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_period.headingLabel}'s report",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Laundry operations summary',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Money',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _MoneySummaryCard(
            collected: collected,
            outstanding: outstanding,
            billed: billed,
            collectedDelta: collected - prevCollected,
            outstandingDelta: outstanding - prevOutstanding,
            billedDelta: billed - prevBilled,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Revenue breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _RevenueBreakdownCard(breakdown: breakdown),
          const SizedBox(height: AppSpacing.md),
          _MonthlyRevenueTrackerCard(series: monthlyRevenue),
          if (showExpenses) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Expenses',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (onAddExpense != null)
                  IconButton(
                    onPressed: onAddExpense,
                    icon: const Icon(Icons.add),
                    tooltip: 'Record an expense',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _ExpensesCard(
              byCategory: expensesByCategory,
              totalSpent: totalExpenses,
              netProfit: netProfit,
              marginPct: marginPct,
              periodLabel: _period.headingLabel,
              onTap: onOpenExpenses,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Unit economics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _UnitEconomicsCard(
            avgOrderValueUgx: avgOrderValue,
            // No priced orders last period → avg is 0, which isn't a real
            // baseline; pass null so the trend chip is hidden rather than
            // showing a spurious full-value jump.
            avgDeltaUgx: prevAvgOrderValue == 0
                ? null
                : avgOrderValue - prevAvgOrderValue,
            estimatedUgx: provisionalRevenue,
            confirmedUgx: finalRevenue,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ReportMetricStrip(
            totalOrders: totalOrders,
            totalItems: totalItems,
            completed: completed,
            pendingWork: pendingWork,
            onOpenOrders: openFilter(OrderFilter.all, 'Orders'),
            onOpenItems: onOpenItems,
            onOpenCompleted: openFilter(
              OrderFilter.completed,
              OrderStatus.completed.label,
            ),
            onOpenPendingWork: openFilter(
              OrderFilter.pendingWork,
              'Pending work',
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Status breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _StatusBreakdownCard(
            pendingPickup: pendingPickup,
            inProgress: inProgress,
            readyForDelivery: readyForDelivery,
            completed: completed,
            totalOrders: totalOrders,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Work summary',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _WorkSummaryCard(
            totalOrders: totalOrders,
            completed: completed,
            pendingWork: pendingWork,
            totalItems: totalItems,
            periodLabel: _period.headingLabel,
          ),
        ],
      ),
    );
  }
}

/// A compact, equal-cell metric strip (Orders / Items / Completed / Pending
/// work). Renders 1×4 on wide surfaces and 2×2 on narrow phones, all within a
/// single card. Replaces the earlier pair of two-up [_ReportMetricCard] rows.
class _ReportMetricStrip extends StatelessWidget {
  const _ReportMetricStrip({
    required this.totalOrders,
    required this.totalItems,
    required this.completed,
    required this.pendingWork,
    this.onOpenOrders,
    this.onOpenItems,
    this.onOpenCompleted,
    this.onOpenPendingWork,
  });

  static const _cellExtent = 140.0;
  static const _wideBreakpoint = 560.0;

  final int totalOrders;
  final int totalItems;
  final int completed;
  final int pendingWork;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenItems;
  final VoidCallback? onOpenCompleted;
  final VoidCallback? onOpenPendingWork;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _ReportMetricData(
        title: 'Orders',
        value: '$totalOrders',
        icon: Icons.assignment_outlined,
        onTap: onOpenOrders,
      ),
      _ReportMetricData(
        title: 'Items',
        value: '$totalItems',
        icon: Icons.inventory_2_outlined,
        onTap: onOpenItems,
      ),
      _ReportMetricData(
        title: OrderStatus.completed.label,
        value: '$completed',
        icon: Icons.check_circle_outline_rounded,
        onTap: onOpenCompleted,
      ),
      _ReportMetricData(
        title: 'Pending work',
        value: '$pendingWork',
        icon: Icons.pending_actions_outlined,
        onTap: onOpenPendingWork,
      ),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _wideBreakpoint) {
            return SizedBox(
              height: _cellExtent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _rowChildren(metrics),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _cellExtent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _rowChildren(metrics.take(2).toList()),
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.cardBorder,
              ),
              SizedBox(
                height: _cellExtent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _rowChildren(metrics.skip(2).toList()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _rowChildren(List<_ReportMetricData> metrics) {
    return [
      for (var i = 0; i < metrics.length; i++) ...[
        Expanded(child: _ReportMetricCell(metric: metrics[i])),
        if (i != metrics.length - 1)
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.cardBorder,
          ),
      ],
    ];
  }
}

class _ReportMetricData {
  const _ReportMetricData({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
}

class _ReportMetricCell extends StatelessWidget {
  const _ReportMetricCell({required this.metric});

  final _ReportMetricData metric;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: metric.onTap != null,
      label: '${metric.title}, ${metric.value}',
      child: InkWell(
        onTap: metric.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.field - 7),
                ),
                child: Icon(metric.icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                metric.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green used for a "good" trend direction; red for "bad" comes from the
/// theme's error colour so it tracks dark/light.
const Color _trendGood = Color(0xFF2E7D32); // green 800

/// A small ▲/▼ + delta chip for period-over-period trends. Renders nothing when
/// there's no change, or when [deltaUgx] is null — meaning there's no comparable
/// prior baseline to trend against (e.g. the previous period had no priced
/// orders), so a raw delta would fabricate a misleading swing from zero.
/// [upIsGood] flips the colour semantics: more collected is good (green up), but
/// more outstanding is bad (red up).
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.deltaUgx, this.upIsGood = true});

  final int? deltaUgx;
  final bool upIsGood;

  @override
  Widget build(BuildContext context) {
    final delta = deltaUgx;
    if (delta == null || delta == 0) return const SizedBox.shrink();
    final up = delta > 0;
    final good = up == upIsGood;
    final color = good ? _trendGood : Theme.of(context).colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          formatUgx(delta.abs()),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The cash-first hero: Collected / Outstanding / Billed, each with a trend
/// chip vs the previous comparable period.
class _MoneySummaryCard extends StatelessWidget {
  const _MoneySummaryCard({
    required this.collected,
    required this.outstanding,
    required this.billed,
    required this.collectedDelta,
    required this.outstandingDelta,
    required this.billedDelta,
  });

  final int collected;
  final int outstanding;
  final int billed;
  final int collectedDelta;
  final int outstandingDelta;
  final int billedDelta;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MoneyRow(
            label: 'Collected',
            amountUgx: collected,
            deltaUgx: collectedDelta,
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          // More money owed is worse, so an upward outstanding trend reads red.
          _MoneyRow(
            label: 'Outstanding',
            amountUgx: outstanding,
            deltaUgx: outstandingDelta,
            upIsGood: false,
          ),
          const Divider(height: AppSpacing.xl),
          _MoneyRow(
            label: 'Billed',
            amountUgx: billed,
            deltaUgx: billedDelta,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amountUgx,
    required this.deltaUgx,
    this.upIsGood = true,
    this.emphasized = false,
  });

  final String label;
  final int amountUgx;
  final int deltaUgx;
  final bool upIsGood;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: emphasized ? 16 : 15,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatUgx(amountUgx),
              style: TextStyle(
                color: emphasized ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: emphasized ? 18 : 16,
              ),
            ),
            _TrendChip(deltaUgx: deltaUgx, upIsGood: upIsGood),
          ],
        ),
      ],
    );
  }
}

/// The net-sales waterfall: gross charge components, discounts, and net sales.
/// Component rows are hidden when zero so the card stays tight; Net sales always
/// shows.
class _RevenueBreakdownCard extends StatelessWidget {
  const _RevenueBreakdownCard({required this.breakdown});

  final RevenueBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, int amount, {bool force = false}) {
      if (amount == 0 && !force) return;
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppSpacing.lg - 2));
      }
      rows.add(_RevenueRow(label: label, amountUgx: amount));
    }

    addRow('Weight charges', breakdown.weightChargeUgx);
    addRow('Line items', breakdown.lineItemsUgx);
    addRow('Express', breakdown.expressUgx);
    addRow('Delivery', breakdown.deliveryUgx);
    addRow('Surcharges', breakdown.surchargesUgx);
    // Discounts reduce the total, so render the negative amount.
    if (breakdown.discountsUgx > 0) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.lg - 2));
      rows.add(_RevenueRow(label: 'Discounts', amountUgx: -breakdown.discountsUgx));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            const Text(
              'No charges recorded yet.',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...rows,
          const Divider(height: AppSpacing.xl),
          _RevenueRow(
            label: 'Net sales',
            amountUgx: breakdown.netSalesUgx,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

/// Unit economics as a single full-width card: average order value is the hero
/// metric (with a period-over-period trend chip for context), and below it a
/// "revenue confidence" proportion bar splits confirmed revenue (orders with a
/// recorded final weight) from estimated revenue (still provisional). Rendered
/// full-width by design so no metric is squeezed into a too-narrow column on
/// small phones.
class _UnitEconomicsCard extends StatelessWidget {
  const _UnitEconomicsCard({
    required this.avgOrderValueUgx,
    required this.avgDeltaUgx,
    required this.estimatedUgx,
    required this.confirmedUgx,
  });

  final int avgOrderValueUgx;

  /// Period-over-period change in average order value, or null when the previous
  /// period has no comparable baseline (no priced orders) — see [_TrendChip].
  final int? avgDeltaUgx;

  /// Revenue from orders still on an estimated (provisional) weight/price.
  final int estimatedUgx;

  /// Revenue from orders whose final weight has been recorded.
  final int confirmedUgx;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = confirmedUgx + estimatedUgx;
    final confirmedFraction = total == 0 ? 0.0 : confirmedUgx / total;
    final confirmedPct = (confirmedFraction * 100).round();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero metric: average order value, with a trend chip vs the previous
          // comparable period.
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.field - 3),
                ),
                child: Icon(Icons.receipt_long_outlined,
                    color: colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Avg order value',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs / 2),
                    // Scale the hero down to fit its column rather than wrapping
                    // onto a second line when the amount is large (many digits)
                    // and the trend chip has squeezed the available width.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatUgx(avgOrderValueUgx),
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              _TrendChip(deltaUgx: avgDeltaUgx),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Revenue confidence',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$confirmedPct% confirmed',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Confirmed vs estimated split, using the same bar language as the
          // status breakdown so the two read consistently.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.chip),
            child: LinearProgressIndicator(
              value: confirmedFraction,
              minHeight: 9,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ConfidenceLegend(
                  label: 'Confirmed',
                  amountUgx: confirmedUgx,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ConfidenceLegend(
                  label: 'Estimated',
                  amountUgx: estimatedUgx,
                  color: colorScheme.primary.withValues(alpha: 0.28),
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One side of the revenue-confidence split: a colour dot + label with the
/// amount beneath it. Stacked (not a single row) so the label and amount never
/// have to share one line on a narrow phone.
class _ConfidenceLegend extends StatelessWidget {
  const _ConfidenceLegend({
    required this.label,
    required this.amountUgx,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final int amountUgx;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs / 2),
        Text(
          formatUgx(amountUgx),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _RevenueRow extends StatelessWidget {
  const _RevenueRow({
    required this.label,
    required this.amountUgx,
    this.emphasized = false,
  });

  final String label;
  final int amountUgx;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: emphasized ? 16 : 15,
            ),
          ),
        ),
        Text(
          formatUgx(amountUgx),
          style: TextStyle(
            color: emphasized ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: emphasized ? 18 : 16,
          ),
        ),
      ],
    );
  }
}

/// A this-month cumulative-revenue tracker: the total earned from completed
/// deliveries so far this calendar month, with a small sparkline of the daily
/// running total. Deliberately independent of the period selector (see the
/// call site in [_DailyReportViewState.build]).
class _MonthlyRevenueSeries {
  const _MonthlyRevenueSeries({
    required this.monthLabel,
    required this.shortMonthLabel,
    required this.totalUgx,
    required this.completedOrders,
    required this.points,
  });

  final String monthLabel;
  final String shortMonthLabel;
  final int totalUgx;
  final int completedOrders;
  final List<_MonthlyRevenuePoint> points;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _monthShortNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  factory _MonthlyRevenueSeries.fromOrders(
    List<LaundryOrder> orders, {
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final dailyTotals = List<int>.filled(localNow.day, 0);
    var completedOrders = 0;

    for (final order in orders) {
      if (order.status != OrderStatus.completed) continue;
      final date = order.relevantDate?.toLocal();
      if (date == null) continue;
      if (date.year != localNow.year || date.month != localNow.month) continue;
      if (date.day > localNow.day) continue;

      dailyTotals[date.day - 1] += order.totalUgx;
      completedOrders++;
    }

    var runningTotal = 0;
    final points = <_MonthlyRevenuePoint>[];
    for (var i = 0; i < dailyTotals.length; i++) {
      runningTotal += dailyTotals[i];
      points.add(_MonthlyRevenuePoint(cumulativeUgx: runningTotal));
    }

    return _MonthlyRevenueSeries(
      monthLabel: '${_monthNames[localNow.month - 1]} ${localNow.year}',
      shortMonthLabel: _monthShortNames[localNow.month - 1],
      totalUgx: runningTotal,
      completedOrders: completedOrders,
      points: points,
    );
  }
}

class _MonthlyRevenuePoint {
  const _MonthlyRevenuePoint({required this.cumulativeUgx});

  final int cumulativeUgx;
}

class _MonthlyRevenueTrackerCard extends StatelessWidget {
  const _MonthlyRevenueTrackerCard({required this.series});

  final _MonthlyRevenueSeries series;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final completedLabel = series.completedOrders == 1
        ? '1 completed delivery'
        : '${series.completedOrders} completed deliveries';

    return AppCard(
      child: Semantics(
        label:
            'This month revenue tracker, ${formatUgx(series.totalUgx)}, '
            '$completedLabel in ${series.monthLabel}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This month revenue tracker',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(series.monthLabel, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                // Flexible so a large month-to-date total cannot claim more than
                // its share of the row and shove the title to zero width; the
                // number then scales down to fit rather than overflowing.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatUgx(series.totalUgx),
                          maxLines: 1,
                          style: textTheme.headlineSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(completedLabel, style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 116,
              width: double.infinity,
              child: CustomPaint(
                painter: _MonthlyRevenueChartPainter(
                  points: series.points,
                  lineColor: colorScheme.primary,
                  gridColor: AppColors.cardBorder,
                  fillColor: colorScheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text('1 ${series.shortMonthLabel}', style: textTheme.bodySmall),
                const Spacer(),
                Text('Today', style: textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyRevenueChartPainter extends CustomPainter {
  const _MonthlyRevenueChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.fillColor,
  });

  final List<_MonthlyRevenuePoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || points.isEmpty) return;

    final chart = Rect.fromLTWH(0, 8, size.width, size.height - 16);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = chart.top + chart.height * fraction;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final maxRevenue = math.max(
      1,
      points.fold<int>(0, (max, p) => math.max(max, p.cumulativeUgx)),
    );

    Offset offsetFor(int index, _MonthlyRevenuePoint point) {
      final x = points.length == 1
          ? chart.left
          : chart.left + (chart.width * index / (points.length - 1));
      final y =
          chart.bottom - (chart.height * point.cumulativeUgx / maxRevenue);
      return Offset(x, y);
    }

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = offsetFor(i, points[i]);
      if (i == 0) {
        linePath.moveTo(offset.dx, offset.dy);
      } else {
        linePath.lineTo(offset.dx, offset.dy);
      }
    }

    final fillPath = Path.from(linePath)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final last = offsetFor(points.length - 1, points.last);
    canvas.drawCircle(
      last,
      7,
      Paint()
        ..color = lineColor.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(last, 4, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _MonthlyRevenueChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _ExpensesCard extends StatelessWidget {
  const _ExpensesCard({
    required this.byCategory,
    required this.totalSpent,
    required this.netProfit,
    required this.marginPct,
    required this.periodLabel,
    this.onTap,
  });

  final Map<ExpenseCategory, int> byCategory;
  final int totalSpent;

  /// Cash collected − total spend (can be negative). Margin is that as a % of
  /// collected.
  final int netProfit;
  final int marginPct;

  /// The current period's noun ("Today" / "This week" / "This month"), used in
  /// the empty-state line so it tracks the selector.
  final String periodLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Iterate the enum so categories always render in a stable, defined order;
    // skip any with no spend today.
    final rows = <Widget>[];
    for (final category in ExpenseCategory.values) {
      final amount = byCategory[category];
      if (amount == null) continue;
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppSpacing.lg - 2));
      }
      rows.add(_RevenueRow(label: category.label, amountUgx: amount));
    }

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            Text(
              'No expenses recorded yet for ${periodLabel.toLowerCase()}.',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...rows,
          const Divider(height: AppSpacing.xl),
          _RevenueRow(
            label: 'Total spent',
            amountUgx: totalSpent,
            emphasized: true,
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          // Net PROFIT = cash collected − total spent. Green-tinted when in the
          // black, error-tinted when spend has outrun collections.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Net profit',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                formatUgx(netProfit),
                style: TextStyle(
                  color: netProfit < 0 ? colorScheme.error : colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Margin $marginPct% of collected',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({
    required this.pendingPickup,
    required this.inProgress,
    required this.readyForDelivery,
    required this.completed,
    required this.totalOrders,
  });

  final int pendingPickup;
  final int inProgress;
  final int readyForDelivery;
  final int completed;
  final int totalOrders;

  @override
  Widget build(BuildContext context) {
    final statusColors =
        Theme.of(context).extension<StatusColors>() ?? StatusColors.light;
    return AppCard(
      child: Column(
        children: [
          _StatusRow(
            label: OrderStatus.pendingPickup.label,
            value: pendingPickup,
            total: totalOrders,
            color: statusColors.of(OrderStatus.pendingPickup).color,
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          _StatusRow(
            label: OrderStatus.inProgress.label,
            value: inProgress,
            total: totalOrders,
            color: statusColors.of(OrderStatus.inProgress).color,
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          _StatusRow(
            label: OrderStatus.readyForDelivery.label,
            value: readyForDelivery,
            total: totalOrders,
            color: statusColors.of(OrderStatus.readyForDelivery).color,
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          _StatusRow(
            label: OrderStatus.completed.label,
            value: completed,
            total: totalOrders,
            color: statusColors.of(OrderStatus.completed).color,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$value/$total',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _WorkSummaryCard extends StatelessWidget {
  const _WorkSummaryCard({
    required this.totalOrders,
    required this.completed,
    required this.pendingWork,
    required this.totalItems,
    required this.periodLabel,
  });

  final int totalOrders;
  final int completed;
  final int pendingWork;
  final int totalItems;

  /// The current period's noun ("Today" / "This week" / "This month") so the
  /// copy follows the selector instead of always reading "today".
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final lower = periodLabel.toLowerCase();
    final message = completed == totalOrders && totalOrders > 0
        ? 'All assigned laundry orders are completed for $lower.'
        : '$pendingWork orders still need attention before $lower is closed.';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "$periodLabel's progress",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Total items handled $lower: $totalItems',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
