import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Demands the second factor from a staff member who has enrolled one.
///
/// Nothing navigates on success: clearing the challenge upgrades the session to
/// aal2 and raises `mfaChallengeVerified`, so [needsMfaChallengeProvider]
/// recomputes and the gate moves on by itself.
class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  Factor? _factor;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFactor();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadFactor() async {
    try {
      final factors = await ref.read(mfaServiceProvider).verifiedFactors();
      if (mounted && factors.isNotEmpty) {
        setState(() => _factor = factors.first);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not reach the server. Please retry.');
      }
    }
  }

  Future<void> _verify() async {
    final factor = _factor;
    if (factor == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(mfaServiceProvider)
          .submitCode(factorId: factor.id, code: _code.text.trim());
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'That code did not match. Try the current one.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text('Two-factor check',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Enter the current 6-digit code from your authenticator '
                      'app.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(labelText: 'Code'),
                      validator: (v) => (v ?? '').trim().length == 6
                          ? null
                          : 'Enter the 6-digit code',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _busy ? null : _verify,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Verify'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // The only way off this screen for someone who has lost
                    // their authenticator. It does not recover the account, but
                    // it returns them to login so a manager can unenrol the
                    // factor for them — without it they are simply stuck.
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => ref.read(authServiceProvider).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
