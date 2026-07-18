import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// `CustomerOrdersRepository.placeOrder` is driven through the `.forTest()` seam
/// (an injected `next_order_code` RPC + insert lambda) so the row it sends to
/// Supabase — attribution, pinned intake/status, minted code — is unit-testable
/// without a live client.
void main() {
  LaundryOrder draft() => const LaundryOrder(
        orderId: 'ord-1',
        customerId: 'cust-1',
        customerName: 'Ada',
        serviceType: ServiceType.washAndIron,
        // A hostile/wrong status+intake on the draft must be overridden by
        // placeOrder to satisfy the customer-insert RLS policy.
        status: OrderStatus.completed,
        intakeMethod: 'walk_in',
        timeLabel: 'Pickup: now',
        itemCount: 3,
        phone: '0700123456',
        address: '12 Kira Rd',
        notes: 'gate code 4',
        fulfillmentMethod: 'delivery',
        estimatedWeightKg: 2.5,
        ratePerKgSnapshotUgx: 5000,
      );

  group('placeOrder', () {
    test('mints the code and pins customer_app intake/status/attribution', () async {
      Map<String, dynamic>? sent;
      final repo = CustomerOrdersRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 9),
        nextOrderCode: () async => 'AMW-2026-0009',
        insertRow: (values) async {
          sent = values;
          return [
            {'id': values['id']}
          ];
        },
      );

      final id = await repo.placeOrder(draft());

      expect(id, 'ord-1');
      expect(sent, isNotNull);
      expect(sent!['id'], 'ord-1');
      expect(sent!['order_code'], 'AMW-2026-0009');
      expect(sent!['intake_method'], 'customer_app');
      expect(sent!['status'], OrderStatus.pendingPickup.toDbString());
      expect(sent!['customer_id'], 'cust-1');
      expect(sent!['placed_by_customer_id'], 'cust-1');
      expect(sent!['created_by'], kCustomerAppSentinelStaffId);
      expect(sent!['intake_recorded_by'], kCustomerAppSentinelStaffId);
      expect(sent!['fulfillment_method'], 'delivery');
      // Ordinary order columns still ride along.
      expect(sent!['customer_name'], 'Ada');
      expect(sent!['estimated_weight_kg'], 2.5);
      expect(sent!['created_at'], DateTime.utc(2026, 7, 18, 9).toIso8601String());
    });

    test('tolerates the row-set RPC shape for the code', () async {
      final repo = CustomerOrdersRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 9),
        nextOrderCode: () async => [
          {'next_order_code': 'AMW-2026-0010'}
        ],
        insertRow: (values) async => [
          {'id': values['id']}
        ],
      );
      Map<String, dynamic>? sent;
      final repo2 = CustomerOrdersRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 9),
        nextOrderCode: () async => [
          {'next_order_code': 'AMW-2026-0010'}
        ],
        insertRow: (values) async {
          sent = values;
          return [
            {'id': values['id']}
          ];
        },
      );
      await repo.placeOrder(draft());
      await repo2.placeOrder(draft());
      expect(sent!['order_code'], 'AMW-2026-0010');
    });

    test('throws when the insert persists no row (RLS drop)', () async {
      final repo = CustomerOrdersRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 9),
        nextOrderCode: () async => 'AMW-2026-0011',
        insertRow: (values) async => const [],
      );
      expect(() => repo.placeOrder(draft()), throwsStateError);
    });

    test('surfaces an empty/blank minted code as a StateError', () async {
      final repo = CustomerOrdersRepository.forTest(
        clock: () => DateTime.utc(2026, 7, 18, 9),
        nextOrderCode: () async => '   ',
        insertRow: (values) async => [
          {'id': values['id']}
        ],
      );
      expect(() => repo.placeOrder(draft()), throwsStateError);
    });
  });
}
