import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/current_staff_provider.dart';
import '../sync/repository_providers.dart';

/// Lets a signed-in user choose a name and password. Reached two ways, both of
/// which establish a session before showing this screen:
///   * accepting an invite link (first-time onboarding), and
///   * completing a password reset.
///
/// The name field is pre-filled from the staff row (the value the inviting
/// manager entered) so the new staff member can confirm or correct their own
/// name on first login. On success it calls [onCompleted] so the parent
/// (AuthGate) can leave the recovery state and route on to the dashboard.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  /// Seed the name field from the staff row exactly once, the first time it
  /// loads — without clobbering anything the user has since typed.
  bool _nameSeeded = false;

  String? _errorMessage;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      // Name first: it's the non-critical step, so a failure here leaves the
      // password unset and the user can simply retry. Password is what releases
      // AuthGate from the recovery state, so set it last.
      await ref.read(staffRepositoryProvider).setMyDisplayName(
            _nameController.text,
          );
      await ref.read(authServiceProvider).updatePassword(
            _passwordController.text,
          );
      // onCompleted drives the parent (AuthGate) — call it even if this screen
      // was torn down mid-request, or the user is stranded on a Set-password
      // screen whose password already saved. (No `mounted` guard here: the
      // callback doesn't touch this widget's State or BuildContext.)
      widget.onCompleted();
    } on AuthFailure catch (e) {
      // Writes this screen's state, so guard like `finally` — unlike
      // onCompleted above, which intentionally drives the parent regardless.
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      // The name RPC (or any other unexpected failure) — surface a generic
      // message rather than a raw Postgrest/network error string.
      if (mounted) {
        setState(() => _errorMessage = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Pre-fill the name with whatever the manager entered at invite time, once
    // the staff row arrives, so the user can confirm or correct it.
    final staff = ref.watch(currentStaffProvider).valueOrNull;
    if (!_nameSeeded && staff != null) {
      // Don't clobber anything the user typed before the staff row arrived; mark
      // seeded either way so a later emission can't overwrite their input.
      if (_nameController.text.isEmpty) _nameController.text = staff.displayName;
      _nameSeeded = true;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Set your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a password to finish setting up your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Your name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'At least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _busy ? null : _save(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v != _passwordController.text)
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save password',
                            style: TextStyle(fontSize: 16)),
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
