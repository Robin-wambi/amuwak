import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mfa_error_text.dart';
import 'recovery_codes_screen.dart';

/// Reports whether two-factor is on after this screen finished with it.
typedef MfaChangedFn = void Function({required bool enabled});

/// Which of the screen's two jobs it is doing.
enum _Stage {
  /// Asking whether a factor already exists — the answer decides everything
  /// below, so nothing is rendered until it lands.
  checking,

  /// No factor yet: show the QR and take a code.
  setup,

  /// Already enrolled: offer to turn it off. Starting a second enrolment here
  /// would collide on the friendly name and dead-end at an error.
  enrolled,

  /// Neither question could be answered.
  failed,
}

/// Manages the authenticator app that acts as a second factor — adding one, or
/// removing the one that is already there.
///
/// Setup starts as soon as the screen opens, because the QR is the whole point
/// of being here — making someone tap "begin" first is a step with no decision
/// in it. But it only starts once the screen knows no factor exists: enrolling
/// over the top of a verified factor fails on the duplicate friendly name, and
/// an already-enrolled staff member tapping the Account entry would get nothing
/// but "could not start two-factor setup" with no way forward.
///
/// The factor Supabase creates is inert until [MfaService.submitCode] verifies
/// it, so abandoning this screen leaves nothing behind that could demand a code
/// the user cannot produce.
class MfaEnrolmentScreen extends ConsumerStatefulWidget {
  const MfaEnrolmentScreen({super.key, required this.onCompleted});

  /// Called once the factor is active, or once it has been removed. The caller
  /// closes this screen — matching [SetPasswordScreen], which reports
  /// completion the same way.
  final MfaChangedFn onCompleted;

  @override
  ConsumerState<MfaEnrolmentScreen> createState() => _MfaEnrolmentScreenState();
}

class _MfaEnrolmentScreenState extends ConsumerState<MfaEnrolmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  _Stage _stage = _Stage.checking;
  TotpEnrolment? _enrolment;
  Factor? _existing;
  bool _busy = false;
  String? _startError;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_stage != _Stage.checking) {
      setState(() {
        _stage = _Stage.checking;
        _startError = null;
      });
    }
    final mfa = ref.read(mfaServiceProvider);
    try {
      final factors = await mfa.verifiedFactors();
      if (!mounted) return;
      if (factors.isNotEmpty) {
        setState(() {
          _existing = factors.first;
          _stage = _Stage.enrolled;
        });
        return;
      }
      final enrolment = await mfa.enrollTotp();
      if (mounted) {
        setState(() {
          _enrolment = enrolment;
          _stage = _Stage.setup;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _startError =
              'Could not start two-factor setup. Please try again.';
        });
      }
    }
  }

  Future<void> _turnOff() async {
    final existing = _existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off two-factor?'),
        content: const Text(
          'Your account will be protected by your password alone. You can '
          'set up an authenticator again at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await ref.read(mfaServiceProvider).removeFactor(existing.id);
      if (mounted) widget.onCompleted(enabled: false);
    } catch (_) {
      // Reporting completion here would tell the user two-factor is off while
      // it is still very much on.
      if (mounted) {
        setState(() =>
            _actionError = 'Could not turn two-factor off. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() async {
    final enrolment = _enrolment;
    if (enrolment == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await ref
          .read(mfaServiceProvider)
          .submitCode(factorId: enrolment.factorId, code: _code.text.trim());
      if (mounted) await _handOverRecoveryCodes();
    } catch (e) {
      // Codes rotate every 30 seconds, so a stale or mistyped code is the
      // ordinary case rather than an exceptional one. Keep the field ready.
      if (mounted) setState(() => _actionError = codeSubmitMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The factor is live but the user has no way back in if they lose it. Hand
  /// over the recovery codes before declaring success — this is the only moment
  /// the plaintext exists.
  Future<void> _handOverRecoveryCodes() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => RecoveryCodesScreen(
          onAcknowledged: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (mounted) widget.onCompleted(enabled: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Two-factor authentication')),
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
    switch (_stage) {
      case _Stage.checking:
        return const Center(child: CircularProgressIndicator());
      case _Stage.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_startError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _start,
              child: const Text('Retry'),
            ),
          ],
        );
      case _Stage.enrolled:
        return _enrolledBody(theme);
      case _Stage.setup:
        return _setupBody(theme, _enrolment!);
    }
  }

  /// What an already-protected account sees. The only action is removal —
  /// adding a second authenticator is not something this app needs, and
  /// attempting it just fails on the duplicate friendly name.
  Widget _enrolledBody(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.verified_user_outlined,
            size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text('Two-factor authentication is on',
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Signing in on a new device asks for a code from your authenticator '
          'app as well as your password.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (_actionError != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_actionError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: _busy ? null : _replaceRecoveryCodes,
          child: const Text('Replace recovery codes'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: _busy ? null : _turnOff,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Turn off'),
        ),
      ],
    );
  }

  /// A fresh set, invalidating the old one — for someone who has spent a code
  /// or lost the paper they wrote them on.
  ///
  /// Deliberately does NOT call [MfaEnrolmentScreen.onCompleted]: unlike
  /// [_turnOff], two-factor stays on, so reporting completion would close this
  /// screen and tell the dashboard the state had changed when it has not.
  ///
  /// Guarded by `_busy` like every other action on this screen — without it,
  /// two taps before the first frame rebuild both push a
  /// [RecoveryCodesScreen]: the second mints a fresh set that deletes the
  /// first's server-side, so acknowledging the first (now-stale) screen and
  /// popping back to it leaves the user looking at codes that no longer work.
  Future<void> _replaceRecoveryCodes() async {
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (routeContext) => RecoveryCodesScreen(
            onAcknowledged: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _setupBody(ThemeData theme, TotpEnrolment enrolment) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scan this with an authenticator app, then enter the 6-digit code '
            'it shows.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: QrImageView(
              data: enrolment.otpauthUri,
              size: 220,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
              gapless: true,
              semanticsLabel: 'Two-factor setup QR code',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Offered because scanning is not always possible: a cracked screen,
          // or a desktop browser with no camera. Locking those staff out of MFA
          // would be worse than showing a secret they already hold.
          Text("Can't scan? Enter this key instead:",
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            enrolment.secret,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _code,
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
          if (_actionError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_actionError!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _activate,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Activate'),
          ),
        ],
      ),
    );
  }
}
