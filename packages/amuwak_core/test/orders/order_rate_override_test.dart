import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sentinel so a test can distinguish "column absent" from "column present but
/// null" when building a Supabase row.
const Object _absent = Object();

Map<String, dynamic> _row({
  Object? rateOverrideReason = _absent,
  Object? rateOverrideFromUgx = _absent,
}) =>
    {
      'id': 'o1',
      'order_code': 'AMW-1',
      'customer_name': 'Ada',
      'phone': '0700',
      'address': 'Kira',
      'service_type': 'Wash only',
      'status': 'pending_pickup',
      'item_count': 1,
      'rate_per_kg_snapshot_ugx': 4000,
      if (!identical(rateOverrideReason, _absent))
        'rate_override_reason': rateOverrideReason,
      if (!identical(rateOverrideFromUgx, _absent))
        'rate_override_from_ugx': rateOverrideFromUgx,
    };

void main() {
  group('LaundryOrder rate-override audit (migration 0059)', () {
    test('fromSupabase parses both audit columns', () {
      final order = LaundryOrder.fromSupabase(
        _row(rateOverrideReason: 'Bulk hostel deal', rateOverrideFromUgx: 5000),
        const [],
      );
      expect(order.rateOverrideReason, 'Bulk hostel deal');
      expect(order.rateOverrideFromUgx, 5000.0);
    });

    test('a row predating the columns degrades to null, not an error', () {
      final order = LaundryOrder.fromSupabase(_row(), const []);
      expect(order.rateOverrideReason, isNull);
      expect(order.rateOverrideFromUgx, isNull);
    });

    test('an explicit null reads as "not overridden"', () {
      final order = LaundryOrder.fromSupabase(
        _row(rateOverrideReason: null, rateOverrideFromUgx: null),
        const [],
      );
      expect(order.rateOverrideReason, isNull);
      expect(order.rateOverrideFromUgx, isNull);
    });

    test('orderUpsertPayload carries both columns to Supabase', () {
      final order = LaundryOrder.fromSupabase(
        _row(rateOverrideReason: 'Bulk hostel deal', rateOverrideFromUgx: 5000),
        const [],
      );
      final payload = orderUpsertPayload(
        order,
        actorStaffId: 'staff-1',
        now: DateTime.utc(2026, 8, 17),
      );
      expect(payload['rate_override_reason'], 'Bulk hostel deal');
      expect(payload['rate_override_from_ugx'], 5000.0);
    });

    test('an ordinary order sends nulls rather than omitting the keys', () {
      // The create_pickup RPC reads these positionally out of p_order; a missing
      // key and an explicit null both cast to NULL, but sending them keeps the
      // payload shape stable across overridden and ordinary orders.
      final payload = orderUpsertPayload(
        LaundryOrder.fromSupabase(_row(), const []),
        actorStaffId: 'staff-1',
        now: DateTime.utc(2026, 8, 17),
      );
      expect(payload.containsKey('rate_override_reason'), isTrue);
      expect(payload['rate_override_reason'], isNull);
      expect(payload['rate_override_from_ugx'], isNull);
    });

    test('participate in equality and hashCode', () {
      // Without this, two orders differing only in why they were repriced would
      // compare equal and a stream could silently drop the corrected one.
      final base = LaundryOrder.fromSupabase(_row(), const []);

      expect(base.copyWith(rateOverrideReason: 'Bulk deal'), isNot(base));
      expect(base.copyWith(rateOverrideFromUgx: 5000), isNot(base));
      expect(
        base.copyWith(rateOverrideReason: 'Bulk deal'),
        base.copyWith(rateOverrideReason: 'Bulk deal'),
      );
      expect(
        base.copyWith(rateOverrideReason: 'Bulk deal').hashCode,
        base.copyWith(rateOverrideReason: 'Bulk deal').hashCode,
      );
    });
  });
}
