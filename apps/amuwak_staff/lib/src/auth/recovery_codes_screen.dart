import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the recovery codes, once.
///
/// This is the only moment the plaintext exists — the server keeps bcrypt
/// hashes and cannot show them again. The screen therefore has no back
/// affordance and no way out except acknowledging: a staff member who taps past
/// it owns a two-factor account with no way back into it.
class RecoveryCodesScreen extends ConsumerStatefulWidget {
  const RecoveryCodesScreen({super.key, required this.onAcknowledged});

  /// Called once the user confirms they have stored the codes. The caller
  /// closes this screen.
  final VoidCallback onAcknowledged;

  @override
  ConsumerState<RecoveryCodesScreen> createState() =>
      _RecoveryCodesScreenState();
}

class _RecoveryCodesScreenState extends ConsumerState<RecoveryCodesScreen> {
  List<String>? _codes;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _mint();
  }

  // Guards against a double tap firing onAcknowledged twice. The check has to
  // happen synchronously, first thing, rather than only disabling the button:
  // two taps delivered before a frame rebuilds would otherwise both reach a
  // still-enabled button in the (stale) widget tree.
  void _acknowledge() {
    if (_busy) return;
    setState(() => _busy = true);
    widget.onAcknowledged();
  }

  Future<void> _mint() async {
    if (_error != null) setState(() => _error = null);
    try {
      final codes = await ref.read(recoveryCodesServiceProvider).generate();
      if (mounted) setState(() => _codes = codes);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not create recovery codes. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // No accidental exit: the codes are unrecoverable once this closes.
      canPop: false,
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
