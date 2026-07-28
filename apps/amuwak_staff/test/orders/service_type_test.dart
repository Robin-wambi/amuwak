import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_core/amuwak_core.dart';

void main() {
  group('ServiceType', () {
    test('has exactly four cases', () {
      expect(ServiceType.values, hasLength(4));
    });

    test('label matches the existing user-facing string for each case', () {
      expect(ServiceType.washAndIron.label, 'Wash & Iron');
      expect(ServiceType.dryCleaning.label, 'Dry cleaning');
      expect(ServiceType.ironOnly.label, 'Iron only');
      expect(ServiceType.washOnly.label, 'Wash only');
    });

    test('toDbString round-trips with fromDbString for every case', () {
      for (final t in ServiceType.values) {
        expect(ServiceType.fromDbString(t.toDbString()), t);
      }
    });

    test('fromDbString throws on unknown input', () {
      expect(
        () => ServiceType.fromDbString('unknown'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
