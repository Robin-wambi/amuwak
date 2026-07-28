/// Returned from `Navigator.pop` when the New Pickup form successfully
/// creates an order. The dashboard branches on [startPickupNow]: if true,
/// it immediately pushes PickupCaptureScreen for the new order.
class NewPickupResult {
  const NewPickupResult({
    required this.orderId,
    required this.startPickupNow,
  });

  final String orderId;
  final bool startPickupNow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewPickupResult &&
          other.orderId == orderId &&
          other.startPickupNow == startPickupNow);

  @override
  int get hashCode => Object.hash(orderId, startPickupNow);
}
