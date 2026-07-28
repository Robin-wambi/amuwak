import 'package:flutter/material.dart';

import 'package:amuwak_core/amuwak_core.dart';
import 'barcode_reader.dart';
import 'barcode_scanner_scaffold.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.expectedOrderCode,
    required this.cameraViewBuilder,
  });

  /// The human-facing order code (e.g. `AMW-2026-0042`) printed on the bag tag —
  /// NOT the internal UUID primary key. This is what the rider scans or types,
  /// so verification compares the scanned value against this code.
  final String expectedOrderCode;
  final CameraViewBuilder cameraViewBuilder;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _showManualEntry = false;
  final TextEditingController _manualController = TextEditingController();
  String? _errorMessage;
  // MobileScanner fires onDetect continuously while a QR code is in view, so
  // we latch on the first matching detection to prevent a second Navigator.pop
  // from firing on a widget that is mid-disposal.
  bool _matched = false;

  // Accepts both the current `AMW-2026-0042` (prefix-year-counter) form and the
  // legacy `AMW-1024` digits-only form, so older printed tags still validate.
  static final RegExp _orderCodePattern =
      RegExp(r'^AMW-(\d{4}-)?\d+$', caseSensitive: false);

  void _handleDetected(String value) {
    if (_matched || !mounted) return;
    final trimmed = value.trim();
    // An empty/blank scan must never count as a match. Without this, a
    // malformed empty expectedOrderCode would satisfy `'' == ''` below and a
    // blank/unreadable scan would silently pass verification.
    if (trimmed.isEmpty) {
      setState(() {
        _errorMessage =
            'This tag does not match order #${widget.expectedOrderCode}.';
        if (_showManualEntry) {
          _manualController.clear();
        }
      });
      return;
    }
    // A rider can type just the order number ("42" / "0042") instead of the
    // full code printed on the bag. We only treat a BARE number that way and
    // match it by counter; a value carrying the AMW-/year format (e.g. a
    // scanned QR from a different year) must still match the full string, so a
    // same-counter tag from another year is correctly rejected below.
    final isBareNumber = isBareOrderNumber(trimmed);
    final expectedNumber = orderCodeNumber(widget.expectedOrderCode);
    final matched = isBareNumber
        ? expectedNumber != null && orderCodeNumber(trimmed) == expectedNumber
        : trimmed.toUpperCase() == widget.expectedOrderCode.toUpperCase();
    if (matched) {
      _matched = true;
      Navigator.pop(context, true);
      return;
    }
    final looksLikeOrderCode = _orderCodePattern.hasMatch(trimmed);
    setState(() {
      _errorMessage = looksLikeOrderCode
          ? 'This tag belongs to order #$trimmed, not #${widget.expectedOrderCode}.'
          : 'This tag does not match order #${widget.expectedOrderCode}.';
      if (_showManualEntry) {
        _manualController.clear();
      }
    });
  }

  void _submitManual() {
    _handleDetected(_manualController.text);
  }

  void _toggleManual() {
    setState(() {
      _showManualEntry = !_showManualEntry;
      _errorMessage = null;
      _manualController.clear();
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BarcodeScannerScaffold(
      onClose: () => Navigator.pop<bool>(context, false),
      child: Column(
        children: [
          Expanded(
            child: _showManualEntry
                ? _ManualEntryView(
                    controller: _manualController,
                    onSubmit: _submitManual,
                    errorMessage: _errorMessage,
                  )
                : widget.cameraViewBuilder(context, _handleDetected),
          ),
          if (!_showManualEntry && _errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: TextButton(
              onPressed: _toggleManual,
              child: Text(
                _showManualEntry
                    ? 'Use camera instead'
                    : 'Enter order code instead',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualEntryView extends StatelessWidget {
  const _ManualEntryView({
    required this.controller,
    required this.onSubmit,
    required this.errorMessage,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Order code written on the bag',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'e.g. 42 or AMW-2026-0042',
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 12),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ElevatedButton(
            onPressed: onSubmit,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
