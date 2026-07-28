import 'package:flutter/material.dart';

import '../proof/barcode_reader.dart';
import '../proof/barcode_scanner_scaffold.dart';

/// A minimal barcode scanner for order search: renders the camera and pops
/// the first raw scanned value back to the caller (or `null` if dismissed).
///
/// Unlike [ScannerScreen] (which validates a scanned tag against an expected
/// order id), search wants whatever code the tag carries so it can drop it
/// into the query, so this screen does no validation.
class BarcodeSearchScanScreen extends StatefulWidget {
  const BarcodeSearchScanScreen({super.key, required this.cameraViewBuilder});

  final CameraViewBuilder cameraViewBuilder;

  @override
  State<BarcodeSearchScanScreen> createState() =>
      _BarcodeSearchScanScreenState();
}

class _BarcodeSearchScanScreenState extends State<BarcodeSearchScanScreen> {
  // MobileScanner fires onDetect continuously while a code is in view; latch on
  // the first detection so a second pop can't fire on a mid-disposal widget.
  bool _matched = false;

  void _handleDetected(String value) {
    if (_matched || !mounted) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _matched = true;
    Navigator.pop<String>(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return BarcodeScannerScaffold(
      onClose: () => Navigator.pop<String>(context, null),
      child: widget.cameraViewBuilder(context, _handleDetected),
    );
  }
}
