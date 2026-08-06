import 'dart:developer' as developer;

import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mfa_error_text.dart';
import 'sign_out_provider.dart';

/// What the screen knows about the enrolled factor. The code form only exists
/// in [ready]: without a factor id there is nothing to verify against, so
/// showing the form earlier would be a Verify button that silently does
/// nothing.
enum _FactorLoad { loading, ready, none, failed }

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
  _FactorLoad _load = _FactorLoad.loading;
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
    // Guarded so the initState call doesn't setState before the first build;
    // on a retry the stage is `failed`, so the spinner does come back.
    if (_load != _FactorLoad.loading) {
      setState(() {
        _load = _FactorLoad.loading;
        _error = null;
      });
    }
    try {
      final factors = await ref.read(mfaServiceProvider).verifiedFactors();
      if (!mounted) return;
      setState(() {
        _factor = factors.isEmpty ? null : factors.first;
        _load = factors.isEmpty ? _FactorLoad.none : _FactorLoad.ready;
      });
    } catch (_) {
      // listFactors() refreshes the session first, so this is a network round
      // trip and failing it is ordinary on a rider's connection.
      if (mounted) setState(() => _load = _FactorLoad.failed);
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
    } catch (e) {
      if (mounted) setState(() => _error = codeSubmitMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Goes through [signOutAndResetFromRef], not `AuthService.signOut()`: the
  /// sync engine has been pulling since sign-in (`syncLifecycleProvider` starts
  /// on any live session, aal1 included), so the local cache is populated by
  /// the time anyone reaches this screen and has to be torn down with it.
  ///
  /// Confirmed first for the same reason the dashboard confirms: that teardown
  /// truncates the outbox too, so a stray tap on the one control this screen
  /// offers would destroy unsynced work.
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Sign out of this device? You will need to sign in again, and any '
          'work still waiting to sync will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await signOutAndResetFromRef(ref);
    } catch (e, st) {
      developer.log('Sign-out failed.',
          name: 'MfaChallenge', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _error = 'Could not sign out. Please try again.');
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
              child: _body(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_load == _FactorLoad.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.shield_outlined, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text('Two-factor check',
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        ..._stageContent(theme),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        ..._actions(theme),
        const SizedBox(height: AppSpacing.sm),
        // The only way off this screen for someone who has lost their
        // authenticator. It does not recover the account, but it returns them
        // to login so a manager can unenrol the factor for them — without it
        // they are simply stuck.
        TextButton(
          onPressed: _busy ? null : _signOut,
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  List<Widget> _stageContent(ThemeData theme) {
    switch (_load) {
      case _FactorLoad.ready:
        return [
          Text(
            'Enter the current 6-digit code from your authenticator app.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: TextFormField(
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
          ),
        ];
      case _FactorLoad.failed:
        return [
          Text(
            'Could not reach the server. Please retry.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ];
      case _FactorLoad.none:
        // The session still says a factor is owed but the account has none —
        // a manager unenrolling it mid-challenge, which is the documented
        // lockout recovery. Say so rather than showing an unsatisfiable form.
        return [
          Text(
            'No authenticator is registered for this account. Sign out and '
            'sign in again — ask a manager if the check keeps appearing.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ];
      case _FactorLoad.loading:
        return const [];
    }
  }

  List<Widget> _actions(ThemeData theme) {
    switch (_load) {
      case _FactorLoad.ready:
        return [
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Verify'),
          ),
        ];
      case _FactorLoad.failed:
        return [
          FilledButton(
            onPressed: _busy ? null : _loadFactor,
            child: const Text('Retry'),
          ),
        ];
      case _FactorLoad.none:
      case _FactorLoad.loading:
        return const [];
    }
  }
}
