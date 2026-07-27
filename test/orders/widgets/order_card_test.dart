import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The order card grows contextual CRUD: visible action icons (a header pencil
/// for Edit, a bottom-right ⋮ overflow for the rest) plus a long-press actions
/// menu (Edit / Mark-as / Delete), with Delete guarded by a confirm dialog. All
/// action callbacks are optional — with none supplied the card is exactly the
/// old tap-only summary, so every existing list keeps working unchanged.
LaundryOrder _order({
  OrderStatus status = OrderStatus.inProgress,
  String id = 'o1',
}) =>
    LaundryOrder(
      orderId: id,
      orderCode: 'AMW-1',
      customerName: 'Ada',
      serviceType: ServiceType.washAndIron,
      status: status,
      timeLabel: 'Today',
      itemCount: 3,
      phone: '0700',
      address: 'Kira',
      notes: '',
    );

/// A freshly-created offline order: no server code yet, so orderCode falls back
/// to the UUID id (hasServerCode == false).
LaundryOrder _placeholder({OrderStatus status = OrderStatus.pendingPickup}) =>
    LaundryOrder(
      orderId: 'a1b2c3d4-e5f6-7890-uuid',
      customerName: 'Ada',
      serviceType: ServiceType.washAndIron,
      status: status,
      timeLabel: 'Today',
      itemCount: 3,
      phone: '0700',
      address: 'Kira',
      notes: '',
    );

LaundryOrder _appOrder() => LaundryOrder(
      orderId: 'o9',
      orderCode: 'AMW-9',
      customerName: 'Ada',
      serviceType: ServiceType.washAndIron,
      status: OrderStatus.pendingPickup,
      timeLabel: 'Today',
      itemCount: 3,
      phone: '0700',
      address: 'Kira',
      notes: '',
      intakeMethod: 'customer_app',
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('customer-app attribution badge', () {
    testWidgets('shows "Placed via app" for a customer_app order',
        (tester) async {
      await tester.pumpWidget(_host(OrderCard(order: _appOrder(), onTap: () {})));
      expect(find.text('Placed via app'), findsOneWidget);
    });

    testWidgets('no badge for a rider/walk-in order', (tester) async {
      await tester.pumpWidget(_host(OrderCard(order: _order(), onTap: () {})));
      expect(find.text('Placed via app'), findsNothing);
    });

    testWidgets('flags damage the customer photographed, so it is spotted in '
        'the list', (tester) async {
      await tester.pumpWidget(_host(OrderCard(
        order: _appOrder().copyWith(cartItems: const [
          CartSnapshotItem(kind: 'weight', name: 'Wash & Iron', estKg: 6),
          CartSnapshotItem(
              kind: 'piece', name: 'Jacket', photoKey: 'customer/c/cart/a.jpg'),
          CartSnapshotItem(
              kind: 'piece', name: 'Shirt', photoKey: 'customer/c/cart/b.jpg'),
        ]),
        onTap: () {},
      )));

      expect(find.text('2 flagged'), findsOneWidget);
    });

    testWidgets('no damage indicator when the cart has no photos',
        (tester) async {
      await tester.pumpWidget(_host(OrderCard(
        order: _appOrder().copyWith(cartItems: const [
          CartSnapshotItem(kind: 'weight', name: 'Wash & Iron', estKg: 6),
        ]),
        onTap: () {},
      )));

      expect(find.text('Placed via app'), findsOneWidget);
      expect(find.textContaining('flagged'), findsNothing);
    });
  });

  group('pending-sync placeholder (offline order with no AMW code yet)', () {
    testWidgets('never shows the raw UUID as the order reference',
        (tester) async {
      await tester.pumpWidget(_host(
        OrderCard(order: _placeholder(), onTap: () {}),
      ));

      expect(find.textContaining('a1b2c3d4'), findsNothing);
      expect(find.textContaining('Pending sync'), findsWidgets);
    });

    testWidgets('a coded order shows its AMW code and no pending indicator',
        (tester) async {
      await tester.pumpWidget(_host(
        OrderCard(order: _order(), onTap: () {}),
      ));

      expect(find.textContaining('AMW-1'), findsOneWidget);
      expect(find.textContaining('Pending sync'), findsNothing);
    });

    testWidgets('the delete confirm names the customer, not the UUID',
        (tester) async {
      await tester.pumpWidget(_host(
        OrderCard(order: _placeholder(), onTap: () {}, onDelete: () {}),
      ));

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final content = (dialog.content as Text).data!;
      expect(content, contains('Ada'));
      expect(content, isNot(contains('a1b2c3d4')));
    });
  });

  group('OrderCard without action callbacks', () {
    testWidgets('renders tap-only and has no Dismissible', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_host(
        OrderCard(order: _order(), onTap: () => tapped = true),
      ));

      expect(find.byType(Dismissible), findsNothing);
      await tester.tap(find.text('Ada'));
      expect(tapped, isTrue);
    });
  });

  group('long-press actions menu', () {
    testWidgets('Edit invokes onEdit', (tester) async {
      var edited = false;
      await tester.pumpWidget(_host(
        OrderCard(
          order: _order(),
          onTap: () {},
          onEdit: () => edited = true,
          onDelete: () {},
          onAdvanceStatus: () {},
        ),
      ));

      await tester.longPress(find.text('Ada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
      expect(edited, isTrue);
    });

    testWidgets('an in-progress order offers Mark as Ready for delivery',
        (tester) async {
      var advanced = false;
      await tester.pumpWidget(_host(
        OrderCard(
          order: _order(status: OrderStatus.inProgress),
          onTap: () {},
          onAdvanceStatus: () => advanced = true,
        ),
      ));

      await tester.longPress(find.text('Ada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Ready for delivery'));
      await tester.pumpAndSettle();
      expect(advanced, isTrue);
    });

    testWidgets(
        'a pending-pickup order routes proof steps to the card tap, not a '
        'proof-less status jump', (tester) async {
      var advanced = false;
      var tapped = false;
      await tester.pumpWidget(_host(
        OrderCard(
          order: _order(status: OrderStatus.pendingPickup),
          onTap: () => tapped = true,
          onAdvanceStatus: () => advanced = true,
        ),
      ));

      await tester.longPress(find.text('Ada'));
      await tester.pumpAndSettle();
      // No proof-less "Mark as In progress" — pickup needs proof capture.
      expect(find.textContaining('Mark as'), findsNothing);
      await tester.tap(find.text('Confirm pickup'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
      expect(advanced, isFalse);
    });
  });

  group('visible action icons (long-press is undiscoverable)', () {
    testWidgets('an Edit icon invokes onEdit without a long-press',
        (tester) async {
      var edited = false;
      await tester.pumpWidget(_host(
        OrderCard(order: _order(), onTap: () {}, onEdit: () => edited = true),
      ));

      final editIcon = find.byTooltip('Edit order');
      expect(editIcon, findsOneWidget);
      await tester.tap(editIcon);
      await tester.pumpAndSettle();
      expect(edited, isTrue);
    });

    testWidgets('the overflow button opens the actions sheet', (tester) async {
      var deleted = false;
      await tester.pumpWidget(_host(
        OrderCard(
          order: _order(),
          onTap: () {},
          onEdit: () {},
          onDelete: () => deleted = true,
        ),
      ));

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      // The same sheet the long-press opens — drive its Delete entry through to
      // the confirm dialog.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('a tap-only card shows neither icon (keeps the chevron)',
        (tester) async {
      await tester.pumpWidget(_host(
        OrderCard(order: _order(), onTap: () {}),
      ));

      expect(find.byTooltip('Edit order'), findsNothing);
      expect(find.byTooltip('More actions'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets(
        'a card with only onEdit shows just the pencil, not a redundant overflow',
        (tester) async {
      await tester.pumpWidget(_host(
        OrderCard(order: _order(), onTap: () {}, onEdit: () {}),
      ));

      expect(find.byTooltip('Edit order'), findsOneWidget);
      // No ⋮ — it would only open a sheet repeating "Edit details".
      expect(find.byTooltip('More actions'), findsNothing);
    });

    testWidgets('a card with only onDelete shows the overflow but no pencil',
        (tester) async {
      await tester.pumpWidget(_host(
        OrderCard(order: _order(), onTap: () {}, onDelete: () {}),
      ));

      expect(find.byTooltip('Edit order'), findsNothing);
      expect(find.byTooltip('More actions'), findsOneWidget);
    });

    testWidgets('the overflow sits in the bottom row; the pencil stays in the '
        'header', (tester) async {
      await tester.pumpWidget(_host(
        OrderCard(
          order: _order(),
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ));

      final chipDy =
          tester.getCenter(find.byIcon(Icons.inventory_2_outlined)).dy;
      final pencilDy = tester.getCenter(find.byTooltip('Edit order')).dy;
      final overflowDy = tester.getCenter(find.byTooltip('More actions')).dy;
      final pillDy = tester.getCenter(find.text('In progress')).dy;

      // Pencil is above the info chips (header); ⋮ is below them, aligned with
      // the status pill at the bottom-right.
      expect(pencilDy, lessThan(chipDy));
      expect(overflowDy, greaterThan(chipDy));
      expect((overflowDy - pillDy).abs(), lessThan(1.0));
    });
  });

  group('delete', () {
    testWidgets('Cancel in the confirm dialog dismisses it without deleting',
        (tester) async {
      var deleted = false;
      await tester.pumpWidget(_host(
        OrderCard(
          order: _order(),
          onTap: () {},
          onDelete: () => deleted = true,
        ),
      ));

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(deleted, isFalse);
    });

    testWidgets('a card with onDelete has no swipe Dismissible — delete is '
        'only via the ⋮ menu', (tester) async {
      await tester.pumpWidget(_host(
        OrderCard(
          order: _order(),
          onTap: () {},
          onDelete: () {},
        ),
      ));

      expect(find.byType(Dismissible), findsNothing);
    });
  });
}
