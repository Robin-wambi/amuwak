import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Adds an authenticator app as a second factor.
///
/// Enrolment starts as soon as the screen opens, because the QR is the whole
/// point of being here — making someone tap "begin" first is a step with no
/// decision in it.
///
/// The factor Supabase creates is inert until [MfaService.submitCode] verifies
/// it, so abandoning this screen leaves nothing behind that could demand a code
/// the user cannot produce.
class MfaEnrolmentScreen extends ConsumerStatefulWidget {
  const MfaEnrolmentScreen({super.key, required this.onCompleted});

  /// Called once the factor is active. The caller closes this screen — matching
  /// [SetPasswordScreen], which reports completion the same way.
  final VoidCallback onCompleted;

  @override
  ConsumerState<MfaEnrolmentScreen> createState() => _MfaEnrolmentScreenState();
}

class _MfaEnrolmentScreenState extends ConsumerState<MfaEnrolmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  TotpEnrolment? _enrolment;
  bool _busy = false;
  String? _startError;
  String? _codeError;

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
    try {
      final enrolment = await ref.read(mfaServiceProvider).enrollTotp();
      if (mounted) setState(() => _enrolment = enrolment);
    } catch (_) {
      if (mounted) {
        setState(() => _startError =
            'Could not start two-factor setup. Please try again.');
      }
    }
  }

  Future<void> _activate() async {
    final enrolment = _enrolment;
    if (enrolment == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      await ref
          .read(mfaServiceProvider)
          .submitCode(factorId: enrolment.factorId, code: _code.text.trim());
      if (mounted) widget.onCompleted();
    } catch (_) {
      // Codes rotate every 30 seconds, so a stale or mistyped code is the
      // ordinary case rather than an exceptional one. Keep the field ready.
      if (mounted) {
        setState(() =>
            _codeError = 'That code did not match. Try the current one.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    if (_startError != null) {
      return Text(_startError!,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error));
    }
    final enrolment = _enrolment;
    if (enrolment == null) {
      return const Center(child: CircularProgressIndicator());
    }
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
          if (_codeError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_codeError!,
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
