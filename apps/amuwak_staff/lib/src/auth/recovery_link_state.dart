import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The URL this app was opened with. A provider so tests can drive it, and
/// safe to read late: the app runs on Flutter web's hash strategy, so in-app
/// navigation only rewrites the fragment and leaves the query alone.
final launchUriProvider = Provider<Uri>((ref) => Uri.base);

/// What bootstrap made of the launch URL. Overridden in `main.dart`; the
/// default covers tests and any path that never ran bootstrap.
final recoveryLinkOutcomeProvider =
    Provider<RecoveryLinkResult>((ref) => RecoveryLinkResult.none);

/// Whether a recovery link arrived and never became a session, which puts the
/// notice on [LoginScreen] instead of leaving a rider to guess.
///
/// Riders reach this the same two ways customers do. The staff app has its own
/// "Forgot password?" and its invites are sent as recovery links (see
/// `invite-staff`), and both apps share one auth project — so one recovery
/// template serves both, and a link shape that can go stale for a customer can
/// go stale for a rider. Detection is [recoveryLinkFailed] in core for exactly
/// that reason; only the way it is shown differs.
final recoveryLinkFailedProvider = Provider<bool>((ref) => recoveryLinkFailed(
      outcome: ref.watch(recoveryLinkOutcomeProvider),
      launchUri: ref.watch(launchUriProvider),
      authStreamHasError: ref.watch(authStateProvider).hasError,
    ));
