import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/payment/cash_tender.dart';

void main() {
  group('computeTender', () {
    test('exact payment: fully applied, no change, nothing left', () {
      final r = computeTender(amountDueUgx: 10000, cashTenderedUgx: 10000);
      expect(r.paymentApplied, 10000);
      expect(r.changeDue, 0);
      expect(r.remainingBalance, 0);
    });

    test('overpayment: applies the due, hands back the change', () {
      final r = computeTender(amountDueUgx: 10000, cashTenderedUgx: 12000);
      expect(r.paymentApplied, 10000);
      expect(r.changeDue, 2000);
      expect(r.remainingBalance, 0);
    });

    test('underpayment: applies the cash, leaves a remaining balance', () {
      final r = computeTender(amountDueUgx: 10000, cashTenderedUgx: 4000);
      expect(r.paymentApplied, 4000);
      expect(r.changeDue, 0);
      expect(r.remainingBalance, 6000);
    });

    test('nothing due: applies nothing, all cash is change', () {
      final r = computeTender(amountDueUgx: 0, cashTenderedUgx: 5000);
      expect(r.paymentApplied, 0);
      expect(r.changeDue, 5000);
      expect(r.remainingBalance, 0);
    });

    test('zero tendered: nothing applied, full balance remains', () {
      final r = computeTender(amountDueUgx: 10000, cashTenderedUgx: 0);
      expect(r.paymentApplied, 0);
      expect(r.changeDue, 0);
      expect(r.remainingBalance, 10000);
    });

    test('negative inputs are clamped to zero', () {
      final r = computeTender(amountDueUgx: -5000, cashTenderedUgx: -100);
      expect(r.paymentApplied, 0);
      expect(r.changeDue, 0);
      expect(r.remainingBalance, 0);
    });
  });
}
