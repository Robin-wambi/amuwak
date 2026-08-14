import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sentinel so a test can distinguish "column absent" from "column present but
/// null" when building a Supabase row.
const Object _absent = Object();

Map<String, dynamic> _row({Object? expectedCollectionAt = _absent}) => {
      'id': 'o1',
      'order_code': 'AMW-1',
      'customer_name': 'Ada',
      'phone': '0700',
      'address': 'Kira',
      'service_type': 'Wash only',
      'status': 'pending_pickup',
      'item_count': 1,
      if (!identical(expectedCollectionAt, _absent))
        'expected_collection_at': expectedCollectionAt,
    };

void main() {
  group('LaundryOrder.expectedCollectionAt', () {
    test('fromSupabase parses the expected_collection_at column', () {
      final when = DateTime.utc(2026, 8, 16, 14);
      final order = LaundryOrder.fromSupabase(
        _row(expectedCollectionAt: when.toIso8601String()),
        const [],
      );
      expect(order.expectedCollectionAt, when);
    });

    test('fromSupabase degrades a missing column to null', () {
      expect(
        LaundryOrder.fromSupabase(_row(), const []).expectedCollectionAt,
        isNull,
      );
    });

    test('fromSupabase degrades a null value to null', () {
      expect(
        LaundryOrder.fromSupabase(_row(expectedCollectionAt: null), const [])
            .expectedCollectionAt,
        isNull,
      );
    });

    test('copyWith sets it, and clearExpectedCollectionAt resets it', () {
      final base = LaundryOrder.fromSupabase(_row(), const []);
      final when = DateTime.utc(2026, 8, 16, 14);

      final withDate = base.copyWith(expectedCollectionAt: when);
      expect(withDate.expectedCollectionAt, when);

      final cleared = withDate.copyWith(clearExpectedCollectionAt: true);
      expect(cleared.expectedCollectionAt, isNull);
    });

    test('participates in equality and hashCode', () {
      final base = LaundryOrder.fromSupabase(_row(), const []);
      final when = DateTime.utc(2026, 8, 16, 14);

      expect(base.copyWith(expectedCollectionAt: when), isNot(base));
      expect(
        base.copyWith(expectedCollectionAt: when),
        base.copyWith(expectedCollectionAt: when),
      );
      expect(
        base.copyWith(expectedCollectionAt: when).hashCode,
        base.copyWith(expectedCollectionAt: when).hashCode,
      );
    });
  });
}
