import 'package:flutter/material.dart';

import 'package:amuwak_staff/src/orders/proof/barcode_reader.dart';

/// Test double for a [CameraViewBuilder]'s viewfinder. Renders a button that,
/// when tapped, fires [onDetected] with [scannedValue] — letting widget tests
/// drive the scan flow without a real camera. Lives in `test/` so it never
/// ships in a release build.
class FakeCameraView extends StatelessWidget {
  const FakeCameraView({
    super.key,
    required this.scannedValue,
    required this.onDetected,
  });

  final String scannedValue;
  final OnBarcodeDetected onDetected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => onDetected(scannedValue),
        child: const Text('Simulate scan'),
      ),
    );
  }
}
