import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_core/amuwak_core.dart';

void main() {
  group('rateFloorUgx', () {
    test('returns the whole-shilling percentage of the default rate', () {
      expect(rateFloorUgx(defaultRateUgx: 5000, minRatePct: 60), 3000);
    });

    test('rounds to whole UGX because shillings have no minor units', () {
      // 4999 * 60% = 2999.4
      expect(rateFloorUgx(defaultRateUgx: 4999, minRatePct: 60), 2999);
    });

    test('a percentage of 0 disables the floor', () {
      expect(rateFloorUgx(defaultRateUgx: 5000, minRatePct: 0), 0);
    });

    test('a negative percentage is treated as disabled, never as a raise', () {
      expect(rateFloorUgx(defaultRateUgx: 5000, minRatePct: -10), 0);
    });
  });

  group('isRateAllowed', () {
    test('permits a rate at or above the floor', () {
      expect(isRateAllowed(rateUgx: 3000, floorUgx: 3000, isManager: false),
          isTrue);
    });

    test('refuses a rate below the floor for a non-manager', () {
      expect(isRateAllowed(rateUgx: 2999, floorUgx: 3000, isManager: false),
          isFalse);
    });

    test('a manager is exempt from the floor', () {
      expect(
          isRateAllowed(rateUgx: 1, floorUgx: 3000, isManager: true), isTrue);
    });

    test('a floor of 0 permits anything', () {
      expect(
          isRateAllowed(rateUgx: 1, floorUgx: 0, isManager: false), isTrue);
    });
  });
}
