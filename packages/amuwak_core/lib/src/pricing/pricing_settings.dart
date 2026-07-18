/// The singleton global pricing configuration (one row in `pricing_settings`).
/// `defaultRatePerKgUgx` is the rate used for any customer without an override;
/// the delivery fee and express surcharge are applied per order at billing time.
class PricingSettings {
  const PricingSettings({
    required this.id,
    required this.defaultRatePerKgUgx,
    required this.updatedAt,
    this.updatedBy,
    this.deliveryFeeUgx = 0,
    this.expressFlatUgx = 0,
    this.expressPct = 0,
  });

  final String id;
  final double defaultRatePerKgUgx;
  final DateTime updatedAt;
  final String? updatedBy;

  /// Flat delivery fee added to an order when delivery is included.
  final int deliveryFeeUgx;

  /// Flat express/turnaround add-on (UGX) applied to express orders.
  final int expressFlatUgx;

  /// Express percentage uplift (e.g. 30 == 30%), on the weight charge + line
  /// items of an express order.
  final double expressPct;

  /// Reads the singleton row. The delivery/express columns degrade to 0 for a
  /// row that predates them being added/backfilled (mirrors the order snapshot's
  /// null-degrade), so a missing column can never error the settings read.
  factory PricingSettings.fromSupabase(Map<String, dynamic> r) =>
      PricingSettings(
        id: r['id'] as String,
        defaultRatePerKgUgx:
            (r['default_rate_per_kg_ugx'] as num).toDouble(),
        updatedAt: DateTime.parse(r['updated_at'] as String),
        updatedBy: r['updated_by'] as String?,
        deliveryFeeUgx: (r['delivery_fee_ugx'] as num?)?.toInt() ?? 0,
        expressFlatUgx: (r['express_surcharge_flat_ugx'] as num?)?.toInt() ?? 0,
        expressPct: (r['express_surcharge_pct'] as num?)?.toDouble() ?? 0,
      );

  PricingSettings copyWith({
    double? defaultRatePerKgUgx,
    int? deliveryFeeUgx,
    int? expressFlatUgx,
    double? expressPct,
  }) =>
      PricingSettings(
        id: id,
        defaultRatePerKgUgx: defaultRatePerKgUgx ?? this.defaultRatePerKgUgx,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
        deliveryFeeUgx: deliveryFeeUgx ?? this.deliveryFeeUgx,
        expressFlatUgx: expressFlatUgx ?? this.expressFlatUgx,
        expressPct: expressPct ?? this.expressPct,
      );
}
