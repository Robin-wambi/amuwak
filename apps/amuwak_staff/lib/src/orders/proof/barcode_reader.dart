import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef OnBarcodeDetected = void Function(String value);

typedef CameraViewBuilder = Widget Function(
  BuildContext context,
  OnBarcodeDetected onDetected,
);

/// Production factory: returns a `CameraViewBuilder` that uses `mobile_scanner`
/// to scan QR codes via the device camera. The first detected barcode's raw
/// value is forwarded to `onDetected`.
CameraViewBuilder mobileScannerCameraViewBuilder() {
  return (context, onDetected) {
    return _MobileScannerView(onDetected: onDetected);
  };
}

class _MobileScannerView extends StatefulWidget {
  const _MobileScannerView({required this.onDetected});

  final OnBarcodeDetected onDetected;

  @override
  State<_MobileScannerView> createState() => _MobileScannerViewState();
}

class _MobileScannerViewState extends State<_MobileScannerView> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;
          if (value != null) {
            widget.onDetected(value);
            return;
          }
        }
      },
    );
  }
}
