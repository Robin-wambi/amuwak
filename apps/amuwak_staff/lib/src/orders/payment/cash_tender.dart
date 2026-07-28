/// The result of tendering cash against an amount owed — the change calculator's
/// output. All values are integer UGX and never negative.
///
/// - [paymentApplied] is what should be recorded against the order (added to its
///   collected total): the cash, capped at what was owed.
/// - [changeDue] is the cash to hand back when the customer overpaid.
/// - [remainingBalance] is what's still owed when the customer underpaid
///   (a partial payment).
///
/// By construction `paymentApplied + remainingBalance == amountDue` and
/// `paymentApplied + changeDue == cashTendered` (for non-negative inputs), so
/// the order's collected total can never exceed its bill.
class TenderResult {
  const TenderResult({
    required this.paymentApplied,
    required this.changeDue,
    required this.remainingBalance,
  });

  final int paymentApplied;
  final int changeDue;
  final int remainingBalance;
}

/// Splits [cashTenderedUgx] against [amountDueUgx] into the amount to record,
/// the change to return, and any balance still owed. The single source of the
/// change math (POS cash-tender rule): the app computes change, the rider only
/// enters what the customer handed over. Negative inputs are clamped to zero so
/// a malformed value can't produce nonsense.
TenderResult computeTender({
  required int amountDueUgx,
  required int cashTenderedUgx,
}) {
  final due = amountDueUgx < 0 ? 0 : amountDueUgx;
  final tendered = cashTenderedUgx < 0 ? 0 : cashTenderedUgx;
  final applied = tendered < due ? tendered : due;
  return TenderResult(
    paymentApplied: applied,
    changeDue: tendered - applied,
    remainingBalance: due - applied,
  );
}
