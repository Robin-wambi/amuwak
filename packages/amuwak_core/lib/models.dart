/// Domain models shared by the staff and customer apps, kept in a library
/// SEPARATE from the wide `amuwak_core.dart` barrel on purpose.
///
/// `Customer`, `ProofEvent`, and the Drift-generated row classes of the same
/// name (in the staff app's `app_database.dart`) collide by name. The staff app
/// imports the wide barrel almost everywhere; if these domain models lived there
/// too, every staff file that also touches the Drift rows would get an
/// `ambiguous_import`. Keeping them here means:
///
/// - the staff app imports these only through its thin local shims
///   (`lib/src/orders/order.dart`, `proof_event.dart`), exactly where it already
///   did — no collision with the Drift rows it gets from `app_database.dart`;
/// - the customer app (which has no Drift layer) imports this library directly
///   for `LaundryOrder`/`Customer`/`ProofEvent` and the write-path payloads.
///
/// Enums/value types these models expose (`ServiceType`, `OrderStatus`,
/// `LineItem`) live in the wide barrel; import `amuwak_core.dart` alongside this.
library;

export 'src/orders/order.dart';
export 'src/orders/proof_event.dart';
export 'src/customers/customer.dart';
export 'src/sync/supabase_payloads.dart';

// Global pricing configuration (singleton row) + its online read/update
// repository. Drift-free; shared by the staff pricing screen and the customer
// app's estimate.
export 'src/pricing/pricing_settings.dart';
export 'src/pricing/pricing_settings_repository.dart';

// Customer-facing, online-only data-access repositories (Supabase `.stream()`
// reads + RLS-gated writes). Consumed by the customer app; the staff app keeps
// its own Drift-backed repositories.
export 'src/sync/orders_customer_repository.dart';
export 'src/sync/order_messages_repository.dart';
export 'src/sync/customer_profile_repository.dart';
