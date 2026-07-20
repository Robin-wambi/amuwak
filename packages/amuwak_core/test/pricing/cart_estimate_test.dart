import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

PricingSettings _settings({
  double rate = 3000,
  int delivery = 5000,
  int expressFlat = 0,
  double expressPct = 30,
}) =>
    PricingSettings(
      id: 's',
      defaultRatePerKgUgx: rate,
      updatedAt: DateTime(2026, 1, 1),
      deliveryFeeUgx: delivery,
      expressFlatUgx: expressFlat,
      expressPct: expressPct,
    );

void main() {
  test('weight only, delivery included, threshold off', () {
    final e = composeCartEstimate(
      estimatedWeightKg: 6,
      pieces: const [],
      settings: _settings(),
      isExpress: false,
      includeDelivery: true,
    );
    expect(e.weightCharge, 18000);
    expect(e.pieceCharge, 0);
    expect(e.subtotal, 18000);
    expect(e.deliveryFee, 5000);
    expect(e.total, 23000);
    expect(e.isProvisional, isTrue);
    expect(e.freeDeliveryApplied, isFalse);
    expect(e.amountToFreeDeliveryUgx, 0);
  });

  test('mixed weight + piece items, qty in the line-item name', () {
    final e = composeCartEstimate(
      estimatedWeightKg: 6,
      pieces: const [CartPieceLine(name: 'Jacket', unitUgx: 8000, qty: 2)],
      settings: _settings(),
      isExpress: false,
      includeDelivery: true,
    );
    expect(e.pieceCharge, 16000);
    expect(e.subtotal, 34000);
    expect(e.deliveryFee, 5000);
    expect(e.total, 39000);
    expect(e.lineItems.single.name, 'Jacket ×2');
    expect(e.lineItems.single.amountUgx, 16000);
  });

  test('express applies the percentage to weight + pieces only', () {
    final e = composeCartEstimate(
      estimatedWeightKg: 6,
      pieces: const [CartPieceLine(name: 'Jacket', unitUgx: 8000, qty: 2)],
      settings: _settings(), // 30%
      isExpress: true,
      includeDelivery: true,
    );
    // 30% of (18000 + 16000) = 10200
    expect(e.expressSurcharge, 10200);
    expect(e.subtotal, 44200);
    expect(e.total, 49200); // + 5000 delivery
  });

  test('per-customer rate overrides the shop default', () {
    final e = composeCartEstimate(
      estimatedWeightKg: 4,
      pieces: const [],
      settings: _settings(rate: 3000),
      customerRatePerKgUgx: 2500,
      isExpress: false,
      includeDelivery: true,
    );
    expect(e.weightCharge, 10000); // 4 × 2500
  });

  test('free delivery waived when subtotal reaches the threshold', () {
    final e = composeCartEstimate(
      estimatedWeightKg: 6,
      pieces: const [CartPieceLine(name: 'Jacket', unitUgx: 8000, qty: 2)],
      settings: _settings(),
      isExpress: false,
      includeDelivery: true,
      freeDeliveryThresholdUgx: 30000,
    );
    expect(e.subtotal, 34000);
    expect(e.freeDeliveryApplied, isTrue);
    expect(e.deliveryFee, 0);
    expect(e.deliveryDiscount, 5000);
    expect(e.total, 34000);
    expect(e.amountToFreeDeliveryUgx, 0);
  });

  test('below threshold reports how much more to add', () {
    final e = composeCartEstimate(
      estimatedWeightKg: 6,
      pieces: const [],
      settings: _settings(),
      isExpress: false,
      includeDelivery: true,
      freeDeliveryThresholdUgx: 30000,
    );
    expect(e.subtotal, 18000);
    expect(e.freeDeliveryApplied, isFalse);
    expect(e.deliveryFee, 5000);
    expect(e.amountToFreeDeliveryUgx, 12000);
  });

  test('customer-collect ignores delivery and the threshold', () {
    final e = composeCartEstimate(
      estimatedWeightKg: 6,
      pieces: const [],
      settings: _settings(),
      isExpress: false,
      includeDelivery: false,
      freeDeliveryThresholdUgx: 30000,
    );
    expect(e.deliveryFee, 0);
    expect(e.deliveryDiscount, 0);
    expect(e.amountToFreeDeliveryUgx, 0);
    expect(e.total, 18000);
  });

  test('empty cart charges nothing, even with delivery included', () {
    final e = composeCartEstimate(
      estimatedWeightKg: 0,
      pieces: const [],
      settings: _settings(),
      isExpress: false,
      includeDelivery: true,
    );
    expect(e.subtotal, 0);
    expect(e.deliveryFee, 0);
    expect(e.total, 0);
  });
}
