import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/expenses/expense.dart';
import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_filter.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/reports/daily_report_screen.dart';

// Default spend date is local Wed 2026-06-17 — matches [_fixedNow] so the
// daily window contains it. Pass [on] to place an expense on another day.
Expense _expense(ExpenseCategory category, int amountUgx, {DateTime? on}) =>
    Expense(
      id: '$category-$amountUgx-${on ?? ''}',
      category: category,
      amountUgx: amountUgx,
      note: '',
      spentAt: on ?? DateTime(2026, 6, 17, 8),
    );

// Fixed reference clock so the report's period window is deterministic in tests.
DateTime _fixedNow() => DateTime(2026, 6, 17, 12);

// Scrolls the (lazily-built) ListView until [finder] is on screen. Used by the
// narrow-phone tests, which pump a short surface where lower sections would
// otherwise be off-screen and not in the tree.
Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    280,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

LaundryOrder _order(
  String id,
  OrderStatus status,
  int totalUgx, {
  int paid = 0,
  DateTime? scheduledFor,
  double? finalWeightKg,
  DateTime? deliveredAt,
}) =>
    LaundryOrder(
      orderId: id,
      orderCode: id,
      customerName: 'X',
      serviceType: ServiceType.washOnly,
      status: status,
      timeLabel: 't',
      itemCount: 1,
      phone: '0700123456',
      address: 'addr',
      notes: '',
      totalUgx: totalUgx,
      paymentAmountUgx: paid,
      scheduledFor: scheduledFor,
      finalWeightKg: finalWeightKg,
      proofEvents: [
        if (deliveredAt != null)
          ProofEvent(
            id: 'delivery-$id',
            type: ProofEventType.delivery,
            capturedAt: deliveredAt,
            count: 1,
            photoPaths: const [],
          ),
      ],
    );

// Pumps the report on a tall surface so the whole (lazily-built) ListView is
// realised — the lower sections (Expenses, Unit economics, metric strip, work
// summary) would otherwise be off-screen and not in the tree to find.
Future<void> _pumpReport(
  WidgetTester tester,
  List<LaundryOrder> orders, {
  List<Expense> expenses = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: DailyReportView(orders: orders, expenses: expenses, now: _fixedNow),
    ),
  ));
}

void main() {
  group('Money summary', () {
    testWidgets('shows collected, outstanding, and billed', (tester) async {
      final orders = [
        _order('A', OrderStatus.completed, 10000, paid: 10000),
        _order('B', OrderStatus.inProgress, 6000, paid: 2000),
      ];

      await _pumpReport(tester, orders);

      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('USh 12,000'), findsWidgets); // 10,000 + 2,000
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('USh 4,000'), findsWidgets); // B: 6,000 - 2,000
      expect(find.text('Billed'), findsOneWidget);
      expect(find.text('USh 16,000'), findsWidgets); // collected + outstanding
    });

    testWidgets('shows an up trend vs the previous day', (tester) async {
      final orders = [
        // Today (in the current daily window).
        _order('today', OrderStatus.completed, 10000,
            paid: 10000, scheduledFor: DateTime(2026, 6, 17, 9)),
        // Yesterday (in the previous daily window).
        _order('yest', OrderStatus.completed, 4000,
            paid: 4000, scheduledFor: DateTime(2026, 6, 16, 9)),
      ];

      await _pumpReport(tester, orders);

      // Collected today (10,000) is up vs yesterday (4,000) → an up indicator.
      expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets);
    });
  });

  group('Revenue breakdown', () {
    testWidgets('splits gross charges, discounts, and net sales',
        (tester) async {
      final priced = LaundryOrder(
        orderId: 'P',
        orderCode: 'P',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.completed,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
        ratePerKgSnapshotUgx: 5000,
        finalWeightKg: 2, // 10,000 weight charge
        lineItems: [LineItem(name: 'Blanket', amountUgx: 8000)],
        isExpress: true,
        expressFlatSnapshotUgx: 1000,
        expressPctSnapshot: 20, // 1000 + 20% of 18000 = 4600
        deliveryFeeSnapshotUgx: 3000,
        manualAdjustmentUgx: -2000,
        totalUgx: 23600,
        paymentAmountUgx: 23600,
      );

      await _pumpReport(tester, [priced]);

      expect(find.text('Revenue breakdown'), findsOneWidget);
      expect(find.text('Weight charges'), findsOneWidget);
      expect(find.text('USh 10,000'), findsWidgets);
      expect(find.text('Line items'), findsOneWidget);
      expect(find.text('USh 8,000'), findsWidgets);
      expect(find.text('Express'), findsOneWidget);
      expect(find.text('USh 4,600'), findsWidgets);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('USh 3,000'), findsWidgets);
      expect(find.text('Discounts'), findsOneWidget);
      expect(find.text('USh -2,000'), findsWidgets);
      expect(find.text('Net sales'), findsOneWidget);
      expect(find.text('USh 23,600'), findsWidgets);
    });
  });

  group('Profit', () {
    testWidgets('shows total spent, net profit, and margin', (tester) async {
      final orders = [
        _order('A', OrderStatus.completed, 10000, paid: 10000),
        _order('B', OrderStatus.completed, 12000, paid: 12000), // collected 22k
        _order('C', OrderStatus.inProgress, 5000), // unpaid
      ];
      final expenses = [
        _expense(ExpenseCategory.detergent, 6000),
        _expense(ExpenseCategory.packaging, 2000), // spent 8,000
      ];

      await _pumpReport(tester, orders, expenses: expenses);

      expect(find.text('Total spent'), findsOneWidget);
      expect(find.text('USh 8,000'), findsWidgets);
      expect(find.text('Net profit'), findsOneWidget);
      expect(find.text('USh 14,000'), findsWidgets); // 22,000 - 8,000
      // Margin = 14,000 / 22,000 collected = 63.6% → 64%.
      expect(find.textContaining('64%'), findsOneWidget);
    });

    testWidgets('net profit goes negative when spend exceeds collected',
        (tester) async {
      final orders = [_order('A', OrderStatus.completed, 10000, paid: 10000)];
      final expenses = [_expense(ExpenseCategory.fuel, 18000)];

      await _pumpReport(tester, orders, expenses: expenses);

      // Net profit = 10,000 collected − 18,000 spent = −8,000.
      expect(find.text('USh -8,000'), findsWidgets);
    });
  });

  group('Unit economics', () {
    testWidgets('shows avg order value hero and the confidence split',
        (tester) async {
      final orders = [
        _order('A', OrderStatus.completed, 10000, paid: 10000, finalWeightKg: 2),
        _order('B', OrderStatus.inProgress, 6000), // estimated (no final wt)
      ];

      await _pumpReport(tester, orders);

      // Hero metric.
      expect(find.text('Avg order value'), findsOneWidget);
      expect(find.text('USh 8,000'), findsWidgets); // 16,000 / 2
      // Revenue-confidence split (renamed from Provisional/Final).
      expect(find.text('Revenue confidence'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Estimated'), findsOneWidget);
      expect(find.textContaining('% confirmed'), findsOneWidget);
    });

    testWidgets('report renders without overflow on a 360px phone',
        (tester) async {
      // The full-width _UnitEconomicsCard replaced a two-column row that
      // overflowed at ~360 (the unbreakable "Provisional" label + its amount
      // did not fit a half-width column). Render the whole report at 360 and
      // assert no RenderFlex overflow was thrown.
      tester.view.physicalSize = const Size(360, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyReportView(
            now: _fixedNow,
            orders: [
              _order('A', OrderStatus.completed, 10000,
                  paid: 10000, finalWeightKg: 2),
              _order('B', OrderStatus.inProgress, 6000),
            ],
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('hides the avg-order-value trend when the previous period '
        'had no priced orders', (tester) async {
      // Today has a priced order; the previous day has none. avgOrderValueUgx
      // returns 0 when nothing is priced, so a raw delta would fabricate a
      // huge "up" chip against a non-existent baseline. The chip must be hidden.
      final orders = [
        _order('today', OrderStatus.completed, 10000,
            paid: 10000, scheduledFor: DateTime(2026, 6, 17, 9)),
      ];

      await _pumpReport(tester, orders);

      expect(find.text('Avg order value'), findsOneWidget);
      final aovCard = find.ancestor(
        of: find.text('Avg order value'),
        matching: find.byType(AppCard),
      );
      expect(
        find.descendant(
            of: aovCard, matching: find.byIcon(Icons.arrow_upward_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(
            of: aovCard, matching: find.byIcon(Icons.arrow_downward_rounded)),
        findsNothing,
      );
    });

    testWidgets('keeps the avg-order-value hero on one line for large amounts '
        'at 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyReportView(
            now: _fixedNow,
            orders: [
              // Two large orders today whose AVERAGE (USh 12,345,678) is the
              // hero — chosen so that value is unique in the tree (it isn't the
              // billed/collected total 24,691,356 nor an estimated-revenue
              // figure). A tiny order yesterday keeps the trend chip rendering,
              // squeezing the hero's column to a narrow width.
              _order('big1', OrderStatus.completed, 20000000,
                  paid: 20000000, scheduledFor: DateTime(2026, 6, 17, 9)),
              _order('big2', OrderStatus.completed, 4691356,
                  paid: 4691356, scheduledFor: DateTime(2026, 6, 17, 10)),
              _order('yest', OrderStatus.completed, 100,
                  paid: 100, scheduledFor: DateTime(2026, 6, 16, 9)),
            ],
          ),
        ),
      ));

      // The hero number must not wrap onto a second line — it should scale down
      // to fit its column instead. A single line of the 22px hero lays out well
      // under 40px tall; a wrapped second line pushes it past that.
      final hero =
          tester.renderObject<RenderParagraph>(find.text('USh 12,345,678'));
      expect(hero.size.height, lessThan(40));
    });
  });

  group('Monthly revenue tracker', () {
    testWidgets('sums current-month completed deliveries only', (tester) async {
      final orders = [
        _order('A', OrderStatus.completed, 10000,
            deliveredAt: DateTime(2026, 6, 1, 10)),
        _order('B', OrderStatus.completed, 12000,
            deliveredAt: DateTime(2026, 6, 17, 9)),
        // Not completed → excluded.
        _order('P', OrderStatus.inProgress, 5000,
            deliveredAt: DateTime(2026, 6, 12, 9)),
        // Previous month → excluded.
        _order('OLD', OrderStatus.completed, 7000,
            deliveredAt: DateTime(2026, 5, 31, 9)),
        // After "now" (day 17) → excluded.
        _order('FUTURE', OrderStatus.completed, 9000,
            deliveredAt: DateTime(2026, 6, 20, 9)),
      ];

      await _pumpReport(tester, orders);

      final tracker = find.ancestor(
        of: find.text('This month revenue tracker'),
        matching: find.byType(AppCard),
      );

      expect(find.descendant(of: tracker, matching: find.text('June 2026')),
          findsOneWidget);
      // Earned = A (10,000) + B (12,000); OLD/FUTURE/P excluded.
      expect(find.descendant(of: tracker, matching: find.text('USh 22,000')),
          findsOneWidget);
      expect(
          find.descendant(
              of: tracker, matching: find.text('2 completed deliveries')),
          findsOneWidget);
      expect(find.descendant(of: tracker, matching: find.byType(CustomPaint)),
          findsWidgets);
    });

    testWidgets('shows zero for an empty current month', (tester) async {
      final orders = [
        _order('OLD', OrderStatus.completed, 7000,
            deliveredAt: DateTime(2026, 5, 31, 9)),
        _order('P', OrderStatus.inProgress, 9000,
            deliveredAt: DateTime(2026, 6, 10, 9)),
      ];

      await _pumpReport(tester, orders);

      final tracker = find.ancestor(
        of: find.text('This month revenue tracker'),
        matching: find.byType(AppCard),
      );

      expect(find.descendant(of: tracker, matching: find.text('USh 0')),
          findsOneWidget);
      expect(
          find.descendant(
              of: tracker, matching: find.text('0 completed deliveries')),
          findsOneWidget);
    });

    testWidgets('keeps the month-to-date total from overflowing the header '
        'at 360px for large totals', (tester) async {
      tester.view.physicalSize = const Size(360, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyReportView(
            now: _fixedNow,
            orders: [
              // A large month-to-date total (USh 24,691,356) makes the tracker's
              // headline number wide. In the header row it must shrink to fit
              // rather than shove the "This month revenue tracker" title to zero
              // width and overflow the row.
              _order('big', OrderStatus.completed, 24691356,
                  paid: 24691356, deliveredAt: DateTime(2026, 6, 17, 9)),
            ],
          ),
        ),
      ));

      expect(tester.takeException(), isNull);

      final tracker = find.ancestor(
        of: find.text('This month revenue tracker'),
        matching: find.byType(AppCard),
      );
      expect(
          find.descendant(
              of: tracker, matching: find.text('USh 24,691,356')),
          findsOneWidget);
    });
  });

  group('Navigation + status (unchanged behaviour)', () {
    testWidgets('each metric cell invokes the right navigation callback',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final filters = <OrderFilter>[];
      final titles = <String?>[];
      var itemsTaps = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyReportView(
            now: _fixedNow,
            orders: [
              _order('A', OrderStatus.completed, 8000),
              _order('B', OrderStatus.inProgress, 5000),
            ],
            onOpenFiltered: (f, {title}) {
              filters.add(f);
              titles.add(title);
            },
            onOpenItems: () => itemsTaps++,
          ),
        ),
      ));

      await _scrollUntilVisible(tester, find.text('Orders'));
      await tester.tap(find.text('Orders'));
      // 'Completed' also appears in the Status breakdown card, so tap the metric
      // cell via its unique icon instead of the ambiguous label.
      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
      await tester.tap(find.text('Pending work'));
      await tester.tap(find.text('Items'));

      expect(filters, [
        OrderFilter.all,
        OrderFilter.completed,
        OrderFilter.pendingWork,
      ]);
      expect(titles, ['Orders', 'Completed', 'Pending work']);
      expect(itemsTaps, 1);
    });

    testWidgets('metric strip uses an equal-cell 2x2 grid below the wide '
        'breakpoint', (tester) async {
      // Below _ReportMetricStrip._wideBreakpoint (560) the strip lays out 2x2.
      // Pumped at 500 rather than a phone-width 360 because the finance-grade
      // _UnitEconomicsRow above the strip has a pre-existing overflow at ~360
      // (the unbreakable "Provisional" label + its amount don't fit its half-
      // width column); that is unrelated to the strip and tracked separately.
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DailyReportView(
            now: _fixedNow,
            orders: [
              _order('A', OrderStatus.completed, 8000),
              _order('B', OrderStatus.inProgress, 5000),
            ],
          ),
        ),
      ));

      await _scrollUntilVisible(tester, find.text('Orders'));

      Finder metricCell(String title) => find
          .ancestor(of: find.text(title), matching: find.byType(InkWell))
          .first;

      final first = tester.getSize(metricCell('Orders'));
      for (final title in const ['Items', 'Completed', 'Pending work']) {
        final size = tester.getSize(metricCell(title));
        expect(size.width, first.width, reason: '$title width');
        expect(size.height, first.height, reason: '$title height');
      }
    });

    testWidgets('cells are inert when no callbacks are provided',
        (tester) async {
      await _pumpReport(tester, [_order('A', OrderStatus.completed, 8000)]);

      await tester.tap(find.text('Orders'), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Completed and Pending work cells show their OrderFilter counts',
        (tester) async {
      final orders = [
        _order('A', OrderStatus.completed, 1000),
        _order('B', OrderStatus.completed, 1000),
        _order('C', OrderStatus.inProgress, 1000),
        _order('D', OrderStatus.pendingPickup, 1000),
        _order('E', OrderStatus.readyForDelivery, 1000),
      ];
      expect(OrderFilter.completed.count(orders), 2);
      expect(OrderFilter.pendingWork.count(orders), 3);

      await _pumpReport(tester, orders);

      Finder valueInCard(IconData icon, String value) => find.descendant(
            of: find.ancestor(
              of: find.byIcon(icon),
              matching: find.byType(AppCard),
            ),
            matching: find.text(value),
          );

      expect(
          valueInCard(Icons.check_circle_outline_rounded, '2'), findsOneWidget);
      expect(valueInCard(Icons.pending_actions_outlined, '3'), findsOneWidget);
    });
  });

  testWidgets('shows the Expenses card with an Add action even when empty',
      (tester) async {
    var addTaps = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DailyReportView(
          orders: const [],
          now: _fixedNow,
          onAddExpense: () => addTaps++,
        ),
      ),
    ));

    // The Expenses card sits well down the report (below Money, Revenue
    // breakdown, and the monthly tracker), so scroll it into the lazy ListView
    // before asserting on it.
    await _scrollUntilVisible(tester, find.text('Expenses'));
    expect(find.text('Expenses'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    expect(addTaps, 1);
  });

  testWidgets('switching Daily→Weekly rescopes the period and its spend',
      (tester) async {
    final expenses = [
      _expense(ExpenseCategory.detergent, 6000), // today (06-17)
      _expense(ExpenseCategory.packaging, 2000), // today (06-17)
      _expense(ExpenseCategory.fuel, 9000,
          on: DateTime(2026, 6, 15, 8)), // Monday — same week, not today
    ];

    await _pumpReport(tester, const [], expenses: expenses);

    expect(find.text("Today's report"), findsOneWidget);
    expect(find.text("Today's progress"), findsOneWidget);
    expect(find.text('USh 8,000'), findsWidgets); // total spent (daily)

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();

    expect(find.text("This week's report"), findsOneWidget);
    expect(find.text("This week's progress"), findsOneWidget);
    expect(find.text('USh 17,000'), findsWidgets); // total spent (weekly)
  });

  testWidgets('DailyReportScreen wraps the report view in a titled Scaffold',
      (tester) async {
    final orders = [
      _order('A', OrderStatus.completed, 8000, paid: 8000),
      _order('B', OrderStatus.inProgress, 5000),
    ];

    await tester.pumpWidget(MaterialApp(home: DailyReportScreen(orders: orders)));

    expect(find.widgetWithText(AppBar, 'Daily report'), findsOneWidget);
    expect(find.byType(DailyReportView), findsOneWidget);
    expect(find.text('Money'), findsOneWidget);
    expect(find.text('USh 8,000'), findsWidgets); // collected (A)
  });
}
