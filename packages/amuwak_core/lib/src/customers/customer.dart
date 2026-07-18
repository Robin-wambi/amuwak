/// A plain, Drift-free customer domain model shared by the staff and customer
/// apps.
///
/// The staff app also has a Drift `Customer` row class (with created/updated/
/// deleted timestamps) used by its local-database write path; this domain model
/// carries only the fields a screen or the customer app cares about. Map between
/// the two at the repository edge in the staff app.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.notes,
    this.email,
    this.customRatePerKgUgx,
    this.authUserId,
  });

  final String id;
  final String name;
  final String phone;
  final String? address;
  final String? notes;
  final String? email;

  /// A per-customer override of the default price-per-kg (null → use the shop
  /// default from `pricing_settings`).
  final double? customRatePerKgUgx;

  /// The linked Supabase auth user id (null for a walk-in customer the shop
  /// created who has not signed up for the customer app).
  final String? authUserId;

  /// Hydrates a [Customer] from a Supabase `customers` row (snake_case JSON).
  factory Customer.fromSupabase(Map<String, dynamic> row) => Customer(
        id: row['id'] as String,
        name: row['name'] as String,
        phone: row['phone'] as String,
        address: row['address'] as String?,
        notes: row['notes'] as String?,
        email: row['email'] as String?,
        customRatePerKgUgx:
            (row['custom_rate_per_kg_ugx'] as num?)?.toDouble(),
        authUserId: row['auth_user_id'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          other.id == id &&
          other.name == name &&
          other.phone == phone &&
          other.address == address &&
          other.notes == notes &&
          other.email == email &&
          other.customRatePerKgUgx == customRatePerKgUgx &&
          other.authUserId == authUserId;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        phone,
        address,
        notes,
        email,
        customRatePerKgUgx,
        authUserId,
      );
}
