import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recovery_link_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _errorMessage;
  bool _busy = false;

  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      // On success the auth state changes and AuthGate swaps in the dashboard,
      // so there's no manual navigation here.
      await ref.read(authServiceProvider).signInWithEmailPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      // Network failures (SocketException, etc.) aren't AuthExceptions, so
      // AuthService doesn't wrap them into AuthFailure — surface a generic
      // message rather than letting them propagate uncaught.
      if (mounted) {
        setState(() => _errorMessage = 'Could not sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (email.isEmpty || !isValidEmail(email)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Sent a password reset link to $email')),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      // Same as _login: network errors aren't wrapped into AuthFailure.
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not send the reset link. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Icon(
                      Icons.local_laundry_service_rounded,
                      color: colorScheme.onPrimary,
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Amuwak Staff',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to manage laundry orders',
                    style: TextStyle(fontSize: 16, color: AppColors.secondaryText),
                  ),
                  if (ref.watch(recoveryLinkFailedProvider)) ...[
                    const SizedBox(height: 24),
                    _RecoveryLinkNotice(
                      linkWasSpent: ref.watch(recoveryLinkOutcomeProvider) ==
                          RecoveryLinkResult.failed,
                    ),
                  ],
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter your email';
                      if (!isValidEmail(value)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _busy ? null : _login(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Enter your password'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadii.field),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says why an emailed recovery link did nothing.
///
/// Without it a rider who opens a dead link lands on a plain sign-in screen —
/// identical to an ordinary visit — with no reason to think the link was the
/// problem, and asks for another one that fails the same way.
///
/// The two causes get different copy because they need different actions, and
/// the wrong one wastes the rider's time: telling someone with a spent token to
/// "try the same browser" sends them hunting a device fault that is not there.
///
/// A notice rather than the customer app's dedicated screen, because this app
/// has no router and its "Forgot password?" is already on this screen — so the
/// fix is one tap below the explanation.
class _RecoveryLinkNotice extends StatelessWidget {
  const _RecoveryLinkNotice({required this.linkWasSpent});

  final bool linkWasSpent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            linkWasSpent
                ? 'That link has already been used'
                : 'That link could not be opened here',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            linkWasSpent
                ? 'Reset links expire, and each one can only be used once. Ask '
                    'for a new one below and open it as soon as it arrives.'
                : 'That link only works in the same browser you asked for it '
                    'from, on the same device. Ask for a new one below and open '
                    'it from this browser.',
            style: TextStyle(color: colorScheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
