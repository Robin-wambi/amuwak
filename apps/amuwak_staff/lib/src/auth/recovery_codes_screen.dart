import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the recovery codes, once.
///
/// This is the only moment the plaintext exists — the server keeps bcrypt
/// hashes and cannot show them again. Once codes are actually on screen there
/// is no way out except acknowledging: a staff member who taps past them owns
/// a two-factor account with no way back into it. Before that — while minting
/// is in progress, or if it failed — there is nothing on screen to protect,
/// so the screen can be left (system back, or the error state's Close
/// action).
///
/// Reports whether the user actually acknowledged the codes by popping
/// itself with a `bool` result: push it with `Navigator.of(context).push<bool>(...)`
/// and treat anything other than `true` (including `null` from
/// a system-back pop) as "no codes were ever shown and saved". Whether that
/// result matters depends on the caller: enrolling a fresh factor MUST NOT
/// report two-factor as successfully turned on unless this returns `true`
/// (see `MfaEnrolmentScreen._handOverRecoveryCodes`), whereas replacing the
/// codes on an already-enrolled account has nothing to report either way.
class RecoveryCodesScreen extends ConsumerStatefulWidget {
  const RecoveryCodesScreen({super.key});

  @override
  ConsumerState<RecoveryCodesScreen> createState() =>
      _RecoveryCodesScreenState();
}

class _RecoveryCodesScreenState extends ConsumerState<RecoveryCodesScreen> {
  List<String>? _codes;
  String? _error;
  bool _busy = false;

  // Guards _mint against re-entrancy, separate from _busy (which only guards
  // acknowledgement). Checked synchronously, first thing, for the same reason
  // _acknowledge below checks _busy synchronously: two taps on Retry
  // delivered before a frame rebuilds would otherwise both reach a
  // still-enabled button in the (stale) widget tree, firing generate() twice.
  // If the second response lands before the first, the first response's
  // setState would win last and show codes the server has already deleted
  // (mint replaces the previous set server-side).
  bool _minting = false;

  @override
  void initState() {
    super.initState();
    _mint();
  }

  // Guards against a double tap popping this screen twice. The check has to
  // happen synchronously, first thing, rather than only disabling the button:
  // two taps delivered before a frame rebuilds would otherwise both reach a
  // still-enabled button in the (stale) widget tree.
  void _acknowledge() {
    if (_busy) return;
    setState(() => _busy = true);
    Navigator.of(context).pop(true);
  }

  Future<void> _mint() async {
    if (_minting) return;
    _minting = true;
    if (_error != null) setState(() => _error = null);
    try {
      final codes = await ref.read(recoveryCodesServiceProvider).generate();
      if (mounted) setState(() => _codes = codes);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not create recovery codes. Please try again. Any '
            'recovery codes you saved earlier may no longer work — '
            'generate a fresh set.');
      }
    } finally {
      _minting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // No accidental exit once codes are actually on screen — they are
      // unrecoverable once this closes. Every other state (loading, or an
      // error with nothing displayed yet) has nothing to protect, so a pop
      // is allowed there: blocking it would trap the user with no way out
      // of a state that has no codes to lose.
      //
      // `!_minting` matters just as much as `_codes == null`: without it, a
      // system-back pop during the FIRST mint (or a Retry mint) is allowed
      // through while generate() is still in flight. That call still commits
      // server-side — the previous set of codes (which may already be in
      // someone's hands) is deleted and replaced with a set nobody ever
      // sees, silently. `_minting` is true synchronously before the first
      // build that can observe it and false again before the rebuild that
      // clears it, so it reads correctly in every state without a race.
      canPop: _codes == null && !_minting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recovery codes'),
          automaticallyImplyLeading: false,
        ),
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
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _mint, child: const Text('Retry')),
          const SizedBox(height: AppSpacing.sm),
          // There are no codes on screen to protect here, so unlike the
          // success state below, this state must have a way out — the
          // PopScope above already permits a system-back pop in this state;
          // this is the explicit affordance for it.
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final codes = _codes;
    if (codes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Save these somewhere safe. If you lose your phone, one of these '
          'codes is how you get back in. Each works once, and they will not be '
          'shown again.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final code in codes) ...[
          SelectableText(code,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: codes.join('\n')));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recovery codes copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy'),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _busy ? null : _acknowledge,
          child: const Text("I've saved these"),
        ),
      ],
    );
  }
}
