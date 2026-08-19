/// The lowest per-kg rate a non-manager may bill an order at.
///
/// [minRatePct] is a whole percentage of [defaultRateUgx] — 60 means "no lower
/// than 60% of the default rate". 0 (or anything below it) disables the floor
/// entirely, which is the shipped default so existing installations are
/// unaffected until a manager sets a value.
///
/// Rounded to whole shillings: UGX has no minor units, and the floor is
/// compared against rates that are themselves rounded before persisting.
int rateFloorUgx({required double defaultRateUgx, required int minRatePct}) {
  if (minRatePct <= 0) return 0;
  return (defaultRateUgx * minRatePct / 100).round();
}

/// Whether [rateUgx] may be billed given [floorUgx].
///
/// A manager is always exempt — the floor exists to bound what a rider can do
/// unilaterally, not to stop the business from pricing as it chooses. A floor
/// of 0 is disabled and permits anything.
///
/// This is the client-side check, for telling the rider before the order is
/// queued. The real boundary is inside the `create_pickup` RPC (migration
/// 0059), which a device cannot bypass.
bool isRateAllowed({
  required double rateUgx,
  required int floorUgx,
  required bool isManager,
}) =>
    isManager || floorUgx <= 0 || rateUgx >= floorUgx;
