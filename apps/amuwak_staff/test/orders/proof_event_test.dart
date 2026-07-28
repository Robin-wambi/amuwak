import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/proof_event.dart';

void main() {
  final pickedAt = DateTime(2026, 5, 12, 9, 42);

  group('ProofEvent', () {
    test('two ProofEvents with identical fields are equal', () {
      final a = ProofEvent(
        id: 'pe-test-1',
        type: ProofEventType.pickup,
        capturedAt: pickedAt,
        count: 12,
        photoPaths: const ['a.jpg', 'b.jpg'],
        notes: 'gate locked',
      );
      final b = ProofEvent(
        id: 'pe-test-1',
        type: ProofEventType.pickup,
        capturedAt: pickedAt,
        count: 12,
        photoPaths: const ['a.jpg', 'b.jpg'],
        notes: 'gate locked',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different type makes events unequal', () {
      final a = ProofEvent(
        id: 'pe-test-1',
        type: ProofEventType.pickup,
        capturedAt: pickedAt,
        count: 12,
        photoPaths: const ['a.jpg'],
      );
      final b = ProofEvent(
        id: 'pe-test-1',
        type: ProofEventType.delivery,
        capturedAt: pickedAt,
        count: 12,
        photoPaths: const ['a.jpg'],
      );

      expect(a, isNot(equals(b)));
    });

    test('different photoPaths order makes events unequal', () {
      final a = ProofEvent(
        id: 'pe-test-1',
        type: ProofEventType.pickup,
        capturedAt: pickedAt,
        count: 1,
        photoPaths: const ['a.jpg', 'b.jpg'],
      );
      final b = ProofEvent(
        id: 'pe-test-1',
        type: ProofEventType.pickup,
        capturedAt: pickedAt,
        count: 1,
        photoPaths: const ['b.jpg', 'a.jpg'],
      );

      expect(a, isNot(equals(b)));
    });

    test('notes default to null when omitted', () {
      final a = ProofEvent(
        id: 'pe-test-1',
        type: ProofEventType.pickup,
        capturedAt: pickedAt,
        count: 1,
        photoPaths: const [],
      );

      expect(a.notes, isNull);
    });

    test('ProofEventType.fromDbString maps known types', () {
      expect(ProofEventType.fromDbString('pickup'), ProofEventType.pickup);
      expect(ProofEventType.fromDbString('delivery'), ProofEventType.delivery);
    });

    test('ProofEventType.fromDbString degrades an unknown type to pickup', () {
      // Must not throw — same stream-safety rationale as OrderStatus.
      expect(ProofEventType.fromDbString('banana'), ProofEventType.pickup);
    });

    test('id is part of equality + hashCode', () {
      final a = ProofEvent(
        id: 'pe-1',
        type: ProofEventType.pickup,
        capturedAt: DateTime.utc(2026, 5, 21, 10),
        count: 3,
        photoPaths: const [],
      );
      final b = ProofEvent(
        id: 'pe-2',
        type: ProofEventType.pickup,
        capturedAt: DateTime.utc(2026, 5, 21, 10),
        count: 3,
        photoPaths: const [],
      );
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });
  });
}
