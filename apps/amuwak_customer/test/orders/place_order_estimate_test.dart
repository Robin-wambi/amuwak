import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/orders/place_order/estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final settings = PricingSettings(
    id: 'ps1',
    defaultRatePerKgUgx: 5000,
    updatedAt: DateTime.utc(2026, 7, 1),
    deliveryFeeUgx: 3000,
    expressFlatUgx: 2000,
    expressPct: 30,
  );

  test('matches recomputeTotal directly and is always provisional', () {
    final est = estimateOrderTotal(
      settings: settings,
      estimatedWeightKg: 4,
      includeDelivery: true,
      isExpress: true,
    );

    final direct = recomputeTotal(const PricingInputs(
      ratePerKgUgx: 5000,
      estimatedWeightKg: 4,
      finalWeightKg: null,
      deliveryFeeUgx: 3000,
      isExpress: true,
      expressFlatUgx: 2000,
      expressPct: 30,
    ));

    expect(est.total, direct.total);
    expect(est.weightCharge, direct.weightCharge);
    expect(est.deliveryFee, direct.deliveryFee);
    expect(est.expressSurcharge, direct.expressSurcharge);
    expect(est.isProvisional, isTrue);
  });

  test('prefers the customer rate override over the default', () {
    final est = estimateOrderTotal(
      settings: settings,
      customerRatePerKgUgx: 4000,
      estimatedWeightKg: 2,
    );
    // 2kg * 4000 = 8000 (no delivery, no express).
    expect(est.weightCharge, 8000);
    expect(est.deliveryFee, 0);
    expect(est.total, 8000);
  });

  test('excludes the delivery fee when the customer will collect', () {
    final est = estimateOrderTotal(
      settings: settings,
      estimatedWeightKg: 2,
      includeDelivery: false,
    );
    expect(est.deliveryFee, 0);
  });

  test('a null weight yields a zero weight charge (still provisional)', () {
    final est = estimateOrderTotal(settings: settings, estimatedWeightKg: null);
    expect(est.weightCharge, 0);
    expect(est.isProvisional, isTrue);
  });
}
