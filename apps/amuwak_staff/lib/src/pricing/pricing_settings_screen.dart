import 'package:flutter/material.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'pricing_settings.dart';

typedef LoadSettingsFn = Future<PricingSettings> Function();
typedef SaveSettingsFn = Future<void> Function({
  required double ratePerKgUgx,
  required int deliveryFeeUgx,
  required int expressFlatUgx,
  required double expressPct,
});

class PricingSettingsScreen extends StatefulWidget {
  const PricingSettingsScreen({
    super.key,
    required this.load,
    required this.save,
    this.onManageCatalog,
  });

  final LoadSettingsFn load;
  final SaveSettingsFn save;

  /// Opens the service item catalog manager. Null hides the entry point (e.g.
  /// in tests that only exercise the rate/fee fields).
  final VoidCallback? onManageCatalog;

  @override
  State<PricingSettingsScreen> createState() => _PricingSettingsScreenState();
}

class _PricingSettingsScreenState extends State<PricingSettingsScreen> {
  final _rateController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _expressFlatController = TextEditingController();
  final _expressPctController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.load();
      if (!mounted) return;
      setState(() {
        _rateController.text = s.defaultRatePerKgUgx.round().toString();
        _deliveryController.text = s.deliveryFeeUgx.toString();
        _expressFlatController.text = s.expressFlatUgx.toString();
        _expressPctController.text = formatPct(s.expressPct);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Pricing settings missing — contact admin.';
        _loading = false;
      });
    }
  }

  /// Parses a non-negative whole-UGX amount; blank reads as 0. Returns null if
  /// the input is non-numeric or negative.
  int? _parseNonNegInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final v = double.tryParse(t)?.roundToDouble();
    if (v == null || v < 0) return null;
    return v.toInt();
  }

  /// Parses a non-negative percentage; blank reads as 0.
  double? _parseNonNegPct(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final v = double.tryParse(t);
    if (v == null || v < 0) return null;
    return v;
  }

  Future<void> _save() async {
    // Rates are displayed and confirmed as whole UGX/kg, so persist the rounded
    // value too. Round before validating so a positive sub-0.5 input can't slip
    // past the ">0" guard and be saved as zero.
    final rate = double.tryParse(_rateController.text.trim())?.roundToDouble();
    if (rate == null || rate <= 0) {
      _snack('Enter a rate greater than 0.');
      return;
    }
    final deliveryFee = _parseNonNegInt(_deliveryController.text);
    final expressFlat = _parseNonNegInt(_expressFlatController.text);
    final expressPct = _parseNonNegPct(_expressPctController.text);
    if (deliveryFee == null || expressFlat == null || expressPct == null) {
      _snack('Fees and percentage must be 0 or more.');
      return;
    }
    // The column is numeric(5,2) (max 999.99); also guards a fat-fingered extra
    // digit from producing a wildly inflated bill.
    if (expressPct >= 1000) {
      _snack('Express percentage must be below 1000.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.save(
        ratePerKgUgx: rate,
        deliveryFeeUgx: deliveryFee,
        expressFlatUgx: expressFlat,
        expressPct: expressPct,
      );
      if (!mounted) return;
      _snack('Pricing settings saved.', clearFirst: true);
    } catch (_) {
      if (!mounted) return;
      _snack('Could not save — please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {bool clearFirst = false}) {
    final messenger = ScaffoldMessenger.of(context);
    if (clearFirst) messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _rateController.dispose();
    _deliveryController.dispose();
    _expressFlatController.dispose();
    _expressPctController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pricing settings')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      _field(
                        label: 'Default rate per kg (UGX)',
                        controller: _rateController,
                        fieldKey: const Key('settings_rate'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _field(
                        label: 'Delivery fee (UGX)',
                        controller: _deliveryController,
                        fieldKey: const Key('settings_delivery_fee'),
                        helper: 'Added to an order when delivery is included.',
                        wholeNumber: true,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Express surcharge',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      _field(
                        label: 'Express flat add-on (UGX)',
                        controller: _expressFlatController,
                        fieldKey: const Key('settings_express_flat'),
                        wholeNumber: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        label: 'Express percentage (%)',
                        controller: _expressPctController,
                        fieldKey: const Key('settings_express_pct'),
                        helper: 'Of weight charge + items, on express orders.',
                      ),
                      if (widget.onManageCatalog != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        OutlinedButton.icon(
                          key: const Key('settings_manage_catalog'),
                          onPressed: widget.onManageCatalog,
                          icon: const Icon(Icons.list_alt),
                          label: const Text('Manage service items'),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(
                        key: const Key('settings_save'),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save'),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required Key fieldKey,
    String? helper,
    bool wholeNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: wholeNumber
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            helperText: helper,
          ),
        ),
      ],
    );
  }
}
