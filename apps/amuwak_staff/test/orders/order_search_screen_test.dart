import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_staff/src/orders/order_search_screen.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';

import '../helpers/fake_camera_view.dart';

const _jane = LaundryOrder(
  orderId: 'AMW-2026-0042',
  orderCode: 'AMW-2026-0042',
  customerName: 'Jane Smith',
  serviceType: ServiceType.washOnly,
  status: OrderStatus.pendingPickup,
  timeLabel: 'Pickup: now',
  itemCount: 3,
  phone: '0700123456',
  address: '12 Kololo Road',
  notes: '',
);

final _bob = _jane.copyWith(
  orderId: 'AMW-2026-0099',
  orderCode: 'AMW-2026-0099',
  customerName: 'Bob Jones',
  status: OrderStatus.completed,
  phone: '0788999000',
  address: '5 Entebbe Lane',
);

final _carol = _jane.copyWith(
  orderId: 'AMW-2026-0100',
  orderCode: 'AMW-2026-0100',
  customerName: 'Carol White',
  status: OrderStatus.inProgress,
  phone: '0752000111',
  address: '9 Ntinda Close',
);

void main() {
  testWidgets('zero-state lists active orders and hides completed ones',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
              (ref) => Stream<List<LaundryOrder>>.value([_jane, _bob, _carol])),
        ],
        child: MaterialApp(
          home: OrderSearchScreen(
            onOrderTap: (_) {},
            cameraViewBuilder: (context, onDetected) => FakeCameraView(
              scannedValue: 'x',
              onDetected: onDetected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Carol White'), findsOneWidget);
    // Completed order is not part of the active zero-state.
    expect(find.text('Bob Jones'), findsNothing);
  });

  testWidgets('typing filters across all orders (including completed)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
              (ref) => Stream<List<LaundryOrder>>.value([_jane, _bob, _carol])),
        ],
        child: MaterialApp(
          home: OrderSearchScreen(
            onOrderTap: (_) {},
            cameraViewBuilder: (context, onDetected) => FakeCameraView(
              scannedValue: 'x',
              onDetected: onDetected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bob');
    await tester.pump(const Duration(milliseconds: 350)); // past debounce
    await tester.pumpAndSettle();
    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Jane Smith'), findsNothing);

    // Address fragment matches too.
    await tester.enterText(find.byType(TextField), 'kololo');
    await tester.pump(const Duration(milliseconds: 350)); // past debounce
    await tester.pumpAndSettle();
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsNothing);
  });

  testWidgets('debounces filtering — applies only after the debounce window',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
              (ref) => Stream<List<LaundryOrder>>.value([_jane, _bob, _carol])),
        ],
        child: MaterialApp(
          home: OrderSearchScreen(
            onOrderTap: (_) {},
            cameraViewBuilder: (context, onDetected) => FakeCameraView(
              scannedValue: 'x',
              onDetected: onDetected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bob');
    // Within the debounce window the filter has NOT applied yet, so the
    // empty-query active zero-state (Jane + Carol, Bob hidden as completed) is
    // still showing.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsNothing);

    // After the window elapses, the filter applies.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Jane Smith'), findsNothing);
  });

  testWidgets('clear button resets back to the zero-state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
              (ref) => Stream<List<LaundryOrder>>.value([_jane, _bob, _carol])),
        ],
        child: MaterialApp(
          home: OrderSearchScreen(
            onOrderTap: (_) {},
            cameraViewBuilder: (context, onDetected) => FakeCameraView(
              scannedValue: 'x',
              onDetected: onDetected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bob');
    await tester.pump(const Duration(milliseconds: 350)); // past debounce
    await tester.pumpAndSettle();
    expect(find.text('Jane Smith'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    // Back to the active zero-state.
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Carol White'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing matches', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
              (ref) => Stream<List<LaundryOrder>>.value([_jane, _bob, _carol])),
        ],
        child: MaterialApp(
          home: OrderSearchScreen(
            onOrderTap: (_) {},
            cameraViewBuilder: (context, onDetected) => FakeCameraView(
              scannedValue: 'x',
              onDetected: onDetected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    await tester.pump(const Duration(milliseconds: 350)); // past debounce
    await tester.pumpAndSettle();

    expect(find.text('No orders found'), findsOneWidget);
    expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
  });

  testWidgets('scanning a tag fills the field and filters to that order',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
              (ref) => Stream<List<LaundryOrder>>.value([_jane, _bob, _carol])),
        ],
        child: MaterialApp(
          home: OrderSearchScreen(
            onOrderTap: (_) {},
            cameraViewBuilder: (context, onDetected) => FakeCameraView(
              scannedValue: 'AMW-2026-0099',
              onDetected: onDetected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.pumpAndSettle();

    // On the scan screen — simulate a detection.
    await tester.tap(find.text('Simulate scan'));
    await tester.pumpAndSettle();

    // Back on search, filtered to the scanned order code.
    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Jane Smith'), findsNothing);
  });

  testWidgets('tapping a result invokes onOrderTap with that order',
      (tester) async {
    LaundryOrder? tapped;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersStreamProvider.overrideWith(
              (ref) => Stream<List<LaundryOrder>>.value([_jane, _bob, _carol])),
        ],
        child: MaterialApp(
          home: OrderSearchScreen(
            onOrderTap: (order) => tapped = order,
            cameraViewBuilder: (context, onDetected) => FakeCameraView(
              scannedValue: 'x',
              onDetected: onDetected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jane Smith'));
    await tester.pumpAndSettle();

    expect(tapped, isNotNull);
    expect(tapped!.orderId, _jane.orderId);
  });

  testWidgets(
    'reuses the memoized matches when query and orders are unchanged',
    (tester) async {
      // Covers the _matchesFor cache-hit branch: once a query has applied, a
      // rebuild with the same _query and the same orders list instance returns
      // the cached matches instead of re-scanning.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersStreamProvider.overrideWith(
                (ref) => Stream<List<LaundryOrder>>.value([_jane, _bob, _carol])),
          ],
          child: MaterialApp(
            home: OrderSearchScreen(
              onOrderTap: (_) {},
              cameraViewBuilder: (context, onDetected) => FakeCameraView(
                scannedValue: 'x',
                onDetected: onDetected,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Apply a query → first scan, result memoized.
      await tester.enterText(find.byType(TextField), 'jane');
      await tester.pump(const Duration(milliseconds: 350)); // past debounce
      await tester.pumpAndSettle();
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsNothing);

      // Append a char: within the debounce window _query is still 'jane' and the
      // orders list instance is unchanged, so the rebuild hits the memo cache.
      await tester.enterText(find.byType(TextField), 'janex');
      await tester.pump(const Duration(milliseconds: 100)); // inside debounce
      // Still showing the 'jane' result (cache hit, no re-scan yet).
      expect(find.text('Jane Smith'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the error state when the orders stream errors',
    (tester) async {
      // Covers ordersAsync.error → EmptyState("Couldn't load orders").
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersStreamProvider.overrideWith(
              (ref) => Stream<List<LaundryOrder>>.error(
                StateError('stream blew up'),
              ),
            ),
          ],
          child: MaterialApp(
            home: OrderSearchScreen(
              onOrderTap: (_) {},
              cameraViewBuilder: (context, onDetected) => FakeCameraView(
                scannedValue: 'x',
                onDetected: onDetected,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load orders"), findsOneWidget);
      expect(find.text('Please try again.'), findsOneWidget);
    },
  );
}
