// `PricingSettingsRepository` moved into `amuwak_core` (Customer App Phase C) so
// both apps share one Supabase read/update path. This re-export keeps the staff
// app's existing relative imports working unchanged.
export 'package:amuwak_core/models.dart'
    show PricingSettingsRepository, FetchRows, UpdateRow;
