/// Public API of the shared Amuwak core package.
///
/// Later tasks add `export 'src/...';` lines here as sources move in.
library;

export 'src/shared/phone.dart';
export 'src/shared/uuid.dart';
export 'src/shared/format_ugx.dart';
export 'src/shared/order_code.dart';
export 'src/shared/email_validation.dart';
export 'src/shared/password_policy.dart';

export 'src/orders/order_status.dart';
export 'src/orders/service_type.dart';
// The staff-facing view of a customer's itemized cart. A value type (no clash
// with the customer app's Drift `CartItem` row), so it lives in the wide barrel
// next to LineItem rather than in models.dart.
export 'src/orders/cart_snapshot_item.dart';

export 'src/shared/theme/app_colors.dart';
export 'src/shared/theme/app_radii.dart';
export 'src/shared/theme/app_spacing.dart';
export 'src/shared/theme/app_elevation.dart';
export 'src/shared/theme/app_motion.dart';
export 'src/shared/theme/app_typography.dart';
export 'src/shared/theme/status_colors.dart';
export 'src/shared/theme/app_card.dart';

export 'src/shared/motion/pressable_scale.dart';
export 'src/shared/motion/count_up_text.dart';
export 'src/shared/motion/reveal_on_mount.dart';
export 'src/shared/motion/animated_gradient_header.dart';

export 'src/shared/widgets/empty_state.dart';
export 'src/shared/widgets/app_theme.dart';

export 'src/orders/pricing/pricing_calculator.dart';
export 'src/orders/pricing/pricing_inputs.dart';
export 'src/orders/pricing/line_item.dart';
export 'src/pricing/cart_estimate.dart';

export 'src/auth/auth_service.dart';
export 'src/auth/mfa_service.dart';
export 'src/auth/recovery_codes_service.dart';
export 'src/auth/recovery_intent_store.dart';
export 'src/auth/recovery_link.dart';
export 'src/auth/session.dart';
export 'src/bootstrap/app_config.dart';
