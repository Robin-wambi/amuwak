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
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    // Seed from the current event so a link opened on cold start is honoured.
    _recovering =
        ref.read(currentAuthEventProvider) == AuthChangeEvent.passwordRecovery;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthChangeEvent?>(currentAuthEventProvider, (prev, next) {
      if (next == AuthChangeEvent.passwordRecovery && !_recovering) {
        setState(() => _recovering = true);
      } else if (next == AuthChangeEvent.signedOut && _recovering) {
        setState(() => _recovering = false);
      }
    });

    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const LoginScreen();
    if (_recovering) {
      return SetPasswordScreen(
        onCompleted: () => setState(() => _recovering = false),
      );
    }
    return const StaffDashboardScreen();
  }
}
