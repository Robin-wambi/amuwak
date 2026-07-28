import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'cash_tender.dart';

/// Called with the amount to record against the order (the change calculator's
/// `paymentApplied` — cash capped at what was owed). The caller adds this to the
/// order's current collected total and persists it.
typedef RecordPaymentFn = Future<void> Function(int paymentAppliedUgx);

/// Common UGX note denominations, largest-first for the quick-tender row.
const _ugxNotes = <int>[50000, 20000, 10000, 5000, 2000, 1000];

/// The change calculator: shows the amount due, takes the cash the customer
/// handed over, and computes the change to give back (overpayment) or the
/// balance still owed (partial payment). Quick-tender buttons fill common notes.
/// Save is injected so the sheet is testable without Riverpod, mirroring
/// [ExpenseEntryScreen].
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({
    super.key,
    required this.amountDueUgx,
    required this.onConfirm,
    this.denominations = _ugxNotes,
  });

  /// What's currently owed on the order (its outstanding balance).
  final int amountDueUgx;
  final RecordPaymentFn onConfirm;
  final List<int> denominations;

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final _tenderedController = TextEditingController();
  bool _saving = false;

  int get _tendered =>
      int.tryParse(_tenderedController.text.trim()) ?? 0;

  void _setTendered(int value) {
    _tenderedController.text = value.toString();
    setState(() {});
  }

  Future<void> _confirm(int applied) async {
    setState(() => _saving = true);
    try {
      await widget.onConfirm(applied);
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record payment — please retry.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _tenderedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = computeTender(
      amountDueUgx: widget.amountDueUgx,
      cashTenderedUgx: _tendered,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record payment', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            _Row(
              label: 'Amount due',
              value: formatUgx(widget.amountDueUgx),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Cash received', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('cash_tendered'),
              controller: _tenderedController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: 'USh ',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ActionChip(
                  key: const Key('quick_tender_exact'),
                  label: const Text('Exact'),
                  onPressed: () => _setTendered(widget.amountDueUgx),
                ),
                for (final note in widget.denominations)
                  ActionChip(
                    key: Key('quick_tender_$note'),
                    label: Text('+${formatUgx(note)}'),
                    onPressed: () => _setTendered(_tendered + note),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (result.changeDue > 0)
              _Row(
                key: const Key('change_due'),
                label: 'Change to give back',
                value: formatUgx(result.changeDue),
                emphasize: true,
                color: theme.colorScheme.primary,
              ),
            if (_tendered > 0 && result.remainingBalance > 0) ...[
              _Row(
                key: const Key('remaining_balance'),
                label: 'Balance still owed',
                value: formatUgx(result.remainingBalance),
                emphasize: true,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Partial payment — the order stays open with a balance.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              key: const Key('record_payment_confirm'),
              onPressed: (_saving || result.paymentApplied == 0)
                  ? null
                  : () => _confirm(result.paymentApplied),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Record ${formatUgx(result.paymentApplied)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: emphasize ? 16 : 15,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: emphasize ? 18 : 16,
          ),
        ),
      ],
    );
  }
}
