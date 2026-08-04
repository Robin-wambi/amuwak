import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/staff_dashboard_screen.dart';
import 'login_screen.dart';
import 'set_password_screen.dart';

/// Root widget that picks the screen from the auth state:
///   * no session            → [LoginScreen]
///   * invite/reset recovery → [SetPasswordScreen]
///   * signed in              → [StaffDashboardScreen]
///
/// The recovery state is sticky: a `passwordRecovery` event (raised when an
/// invite or reset link is opened) keeps us on [SetPasswordScreen] until the
/// user sets a password — a later token refresh must not bump them off it early.
///
/// Sticky across a relaunch too, via [RecoveryIntentStore]. Widget state alone
/// was not enough: the Supabase session persists but `passwordRecovery` does
/// not repeat — reopening the PWA restores the stored session and raises
/// `initialSession` — so a rider who reloaded mid-reset was handed the
/// dashboard with their old password still live.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _recovering = false;

  RecoveryIntentStore get _intent => ref.read(recoveryIntentStoreProvider);

  @override
  void initState() {
    super.initState();
    // Seed from the current event so a link opened on cold start is honoured,
    // then fall back to what a previous run recorded — a relaunch replays
    // `initialSession`, never a second `passwordRecovery`.
    if (ref.read(currentAuthEventProvider) ==
        AuthChangeEvent.passwordRecovery) {
      _intent.markPending();
      _recovering = true;
    } else {
      _recovering = _intent.isPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthChangeEvent?>(currentAuthEventProvider, (prev, next) {
      if (next == AuthChangeEvent.passwordRecovery && !_recovering) {
        _intent.markPending();
        setState(() => _recovering = true);
      } else if (next == AuthChangeEvent.signedOut && _recovering) {
        _intent.clear();
        setState(() => _recovering = false);
      }
    });

    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const LoginScreen();
    if (_recovering) {
      return SetPasswordScreen(
        onCompleted: () {
          _intent.clear();
          setState(() => _recovering = false);
        },
      );
    }
    return const StaffDashboardScreen();
  }
}
