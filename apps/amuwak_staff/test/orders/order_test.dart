import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';

void main() {
  const a = LaundryOrder(
    orderId: 'AMW-1',
    customerName: 'A',
    serviceType: ServiceType.washOnly,
    status: OrderStatus.pendingPickup,
    timeLabel: 't',
    itemCount: 1,
    phone: 'p',
    address: 'addr',
    notes: 'n',
  );

  test('two LaundryOrders with the same fields are equal', () {
    const b = LaundryOrder(
      orderId: 'AMW-1',
      customerName: 'A',
      serviceType: ServiceType.washOnly,
      status: OrderStatus.pendingPickup,
      timeLabel: 't',
      itemCount: 1,
      phone: 'p',
      address: 'addr',
      notes: 'n',
    );

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('copyWith with a new status produces a non-equal order', () {
    final updated = a.copyWith(status: OrderStatus.inProgress);

    expect(updated, isNot(equals(a)));
    expect(updated.hashCode, isNot(equals(a.hashCode)));
  });

  test('orders with same-length but differing line items are not equal', () {
    final withBlanket =
        a.copyWith(lineItems: [LineItem(name: 'Blanket', amountUgx: 8000)]);
    final withJacket =
        a.copyWith(lineItems: [LineItem(name: 'Jacket', amountUgx: 8000)]);
    final withBlanketAgain =
        a.copyWith(lineItems: [LineItem(name: 'Blanket', amountUgx: 8000)]);

    expect(withBlanket, isNot(equals(withJacket)));
    expect(withBlanket, equals(withBlanketAgain));
  });

  group('LaundryOrder.proofEvents', () {
    final pickupEvent = ProofEvent(
      id: 'pe-test-1',
      type: ProofEventType.pickup,
      capturedAt: DateTime(2026, 5, 12, 9, 42),
      count: 12,
      photoPaths: const ['pickup_0.jpg'],
    );
    final deliveryEvent = ProofEvent(
      id: 'pe-test-2',
      type: ProofEventType.delivery,
      capturedAt: DateTime(2026, 5, 12, 16, 13),
      count: 12,
      photoPaths: const ['delivery_0.jpg'],
    );

    test('defaults to an empty list', () {
      expect(a.proofEvents, isEmpty);
      expect(a.hasPickupProof, isFalse);
      expect(a.hasDeliveryProof, isFalse);
      expect(a.pickupProof, isNull);
      expect(a.deliveryProof, isNull);
    });

    test('pickupProof returns the first pickup event', () {
      final order = a.copyWith(proofEvents: [pickupEvent, deliveryEvent]);

      expect(order.pickupProof, equals(pickupEvent));
      expect(order.hasPickupProof, isTrue);
    });

    test('deliveryProof returns the first delivery event', () {
      final order = a.copyWith(proofEvents: [pickupEvent, deliveryEvent]);

      expect(order.deliveryProof, equals(deliveryEvent));
      expect(order.hasDeliveryProof, isTrue);
    });

    test('value equality includes proofEvents', () {
      final withEvents = a.copyWith(proofEvents: [pickupEvent]);
      final withSameEvents = a.copyWith(proofEvents: [pickupEvent]);
      final withDifferentEvents = a.copyWith(proofEvents: [deliveryEvent]);

      expect(withEvents, equals(withSameEvents));
      expect(withEvents.hashCode, equals(withSameEvents.hashCode));
      expect(withEvents, isNot(equals(withDifferentEvents)));
    });

    test('copyWith preserves proofEvents when omitted', () {
      final original = a.copyWith(proofEvents: [pickupEvent]);
      final updated = original.copyWith(status: OrderStatus.inProgress);

      expect(updated.proofEvents, equals([pickupEvent]));
    });
  });

  group('LaundryOrder new fields (Plan PR-B)', () {
    test('orderCode defaults to orderId when not specified', () {
      const o = LaundryOrder(
        orderId: 'AMW-X1',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(o.orderCode, 'AMW-X1');
    });

    test('orderCode can be set distinctly from orderId', () {
      const o = LaundryOrder(
        orderId: 'uuid-1',
        orderCode: 'AMW-123',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(o.orderCode, 'AMW-123');
      expect(o.orderId, 'uuid-1');
    });

    test('hasServerCode is false while the code is still the placeholder', () {
      // A freshly-created offline order carries its UUID id as the placeholder
      // order_code (orderCode ?? orderId), so the real AMW code isn't assigned.
      const placeholder = LaundryOrder(
        orderId: 'a1b2c3d4-uuid',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(placeholder.hasServerCode, isFalse);
      expect(placeholder.referenceLabel, 'Pending sync');
    });

    test('hasServerCode is true once the real AMW code has backfilled', () {
      const coded = LaundryOrder(
        orderId: 'a1b2c3d4-uuid',
        orderCode: 'AMW-2026-0042',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(coded.hasServerCode, isTrue);
      expect(coded.referenceLabel, 'AMW-2026-0042');
    });

    test('intakeMethod defaults to driver_pickup', () {
      const o = LaundryOrder(
        orderId: 'X',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(o.intakeMethod, 'driver_pickup');
    });

    test('fulfillmentMethod defaults to delivery', () {
      const o = LaundryOrder(
        orderId: 'X',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(o.fulfillmentMethod, 'delivery');
    });

    test('customerId and scheduledFor default to null', () {
      const o = LaundryOrder(
        orderId: 'X',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(o.customerId, isNull);
      expect(o.scheduledFor, isNull);
    });

    test('copyWith preserves new fields when omitted', () {
      final scheduled = DateTime(2026, 6, 1, 9);
      final o = LaundryOrder(
        orderId: 'uuid-1',
        orderCode: 'AMW-123',
        customerId: 'cust-1',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
        intakeMethod: 'walk_in',
        fulfillmentMethod: 'walk_out',
        scheduledFor: scheduled,
      );
      final copy = o.copyWith(itemCount: 2);
      expect(copy.orderCode, 'AMW-123');
      expect(copy.customerId, 'cust-1');
      expect(copy.intakeMethod, 'walk_in');
      expect(copy.fulfillmentMethod, 'walk_out');
      expect(copy.scheduledFor, scheduled);
      expect(copy.itemCount, 2);
    });

    test('copyWith with a blank orderCode preserves the existing code', () {
      const o = LaundryOrder(
        orderId: 'uuid-1',
        orderCode: 'AMW-123',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(o.copyWith(orderCode: '').orderCode, 'AMW-123');
      expect(o.copyWith(orderCode: '   ').orderCode, 'AMW-123');
    });

    test('copyWith with clearScheduledFor: true nulls out scheduledFor', () {
      final o = LaundryOrder(
        orderId: 'X',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
        scheduledFor: DateTime(2026, 6, 1, 9),
      );
      final cleared = o.copyWith(clearScheduledFor: true);
      expect(cleared.scheduledFor, isNull);
    });

    group('formatScheduled', () {
      DateTime fixedNow() => DateTime(2026, 5, 26, 10);

      test('uses "Today" when scheduled date matches now', () {
        expect(
          LaundryOrder.formatScheduled(DateTime(2026, 5, 26, 14, 15),
              now: fixedNow),
          'Today, 2:15 PM',
        );
      });

      test('uses "Tomorrow" when scheduled is the next day', () {
        expect(
          LaundryOrder.formatScheduled(DateTime(2026, 5, 27, 9, 0),
              now: fixedNow),
          'Tomorrow, 9:00 AM',
        );
      });

      test('uses weekday + month for dates further out', () {
        expect(
          LaundryOrder.formatScheduled(DateTime(2026, 6, 1, 9, 0),
              now: fixedNow),
          'Mon 1 Jun, 9:00 AM',
        );
      });
    });

    group('formatDay', () {
      // 26 May 2026 is a Tuesday; 1 Jun 2026 is a Monday (see formatScheduled).
      DateTime fixedNow() => DateTime(2026, 5, 26, 10);

      test('"Today" when the date matches now (time ignored)', () {
        expect(
          LaundryOrder.formatDay(DateTime(2026, 5, 26, 14, 15), now: fixedNow),
          'Today',
        );
      });

      test('"Tomorrow" for the next day', () {
        expect(
          LaundryOrder.formatDay(DateTime(2026, 5, 27, 9), now: fixedNow),
          'Tomorrow',
        );
      });

      test('"Yesterday" for the previous day', () {
        expect(
          LaundryOrder.formatDay(DateTime(2026, 5, 25, 9), now: fixedNow),
          'Yesterday',
        );
      });

      test('weekday + day + month for dates further out', () {
        expect(
          LaundryOrder.formatDay(DateTime(2026, 6, 1, 9), now: fixedNow),
          'Mon 1 Jun',
        );
      });

      test('weekday + day + month for dates further in the past', () {
        expect(
          LaundryOrder.formatDay(DateTime(2026, 5, 20, 9), now: fixedNow),
          'Wed 20 May',
        );
      });
    });

    group('relevantDate', () {
      final pickupAt = DateTime(2026, 5, 12, 9, 42);
      final deliveryAt = DateTime(2026, 5, 12, 16, 13);
      final scheduled = DateTime(2026, 6, 1, 9);
      ProofEvent pickup() => ProofEvent(
            id: 'pe-p',
            type: ProofEventType.pickup,
            capturedAt: pickupAt,
            count: 1,
            photoPaths: const [],
          );
      ProofEvent delivery() => ProofEvent(
            id: 'pe-d',
            type: ProofEventType.delivery,
            capturedAt: deliveryAt,
            count: 1,
            photoPaths: const [],
          );

      test('completed → delivery proof time', () {
        final o = a.copyWith(
          status: OrderStatus.completed,
          scheduledFor: scheduled,
          proofEvents: [pickup(), delivery()],
        );
        expect(o.relevantDate, deliveryAt);
      });

      test('completed without delivery proof → scheduledFor', () {
        final o = a.copyWith(
          status: OrderStatus.completed,
          scheduledFor: scheduled,
        );
        expect(o.relevantDate, scheduled);
      });

      test('non-completed with a schedule → scheduledFor', () {
        final o = a.copyWith(
          status: OrderStatus.inProgress,
          scheduledFor: scheduled,
          proofEvents: [pickup()],
        );
        expect(o.relevantDate, scheduled);
      });

      test('non-completed, no schedule → pickup proof time', () {
        final o = a.copyWith(
          status: OrderStatus.inProgress,
          proofEvents: [pickup()],
        );
        expect(o.relevantDate, pickupAt);
      });

      test('immediate order with neither → null', () {
        final o = a.copyWith(status: OrderStatus.pendingPickup);
        expect(o.relevantDate, isNull);
      });
    });

    group('computeTimeLabel', () {
      DateTime fixedNow() => DateTime(2026, 5, 26, 10);

      test("returns 'Pickup: now' when scheduledFor is null", () {
        expect(
          LaundryOrder.computeTimeLabel(
            scheduledFor: null,
            now: fixedNow,
          ),
          'Pickup: now',
        );
      });

      test('returns formatScheduled output when scheduledFor is set', () {
        expect(
          LaundryOrder.computeTimeLabel(
            scheduledFor: DateTime(2026, 5, 27, 9, 0),
            now: fixedNow,
          ),
          'Tomorrow, 9:00 AM',
        );
      });
    });

    test('copyWith with clearCustomerId: true nulls out customerId', () {
      const o = LaundryOrder(
        orderId: 'X',
        customerId: 'cust-9',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      final cleared = o.copyWith(clearCustomerId: true);
      expect(cleared.customerId, isNull);
    });

    test('equality includes the new fields', () {
      const base = LaundryOrder(
        orderId: 'X',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      final withCode = base.copyWith();
      expect(withCode, equals(base));

      const differentCode = LaundryOrder(
        orderId: 'X',
        orderCode: 'AMW-OTHER',
        customerName: 'X',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 't',
        itemCount: 1,
        phone: 'p',
        address: 'a',
        notes: '',
      );
      expect(differentCode, isNot(equals(base)));
    });
  });
}
