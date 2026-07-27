import '../data/app_database.dart' show Customer;

/// The Drift-free order/proof payload builders moved into `amuwak_core`
/// (Customer App Phase C) so the customer app can reuse them; re-exported here
/// so the staff app's existing imports of this file keep resolving them.
export 'package:amuwak_core/models.dart'
    show
        orderUpsertPayload,
        orderStatusUpdatePayload,
        orderPaymentUpdatePayload,
        orderDetailsUpdatePayload,
        orderSoftDeletePayload,
        proofEventUpsertPayload;

/// Staff-only write-path builder: Drift `Customer` row → snake_case Supabase
/// row map. It stays in the staff app because it reads the Drift row's
/// `created_at` (preserved on upsert) — a local-DB concern the customer app
/// does not have (customers link via the `link_or_create_customer` RPC, which
/// stamps `created_at` server-side).
Map<String, dynamic> customerUpsertPayload(
  Customer customer, {
  required DateTime now,
}) =>
    {
      'id': customer.id,
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address,
      'notes': customer.notes,
      'custom_rate_per_kg_ugx': customer.customRatePerKgUgx,
      'created_at': customer.createdAt.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };
