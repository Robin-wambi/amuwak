import 'package:flutter/material.dart';

/// Shared chrome for the order-tag scanner screens: the themed [Scaffold] +
/// [AppBar] (titled "Scan order tag" with a close button) + [SafeArea]. Both
/// [ScannerScreen] (proof verification) and `BarcodeSearchScanScreen` (search)
/// render their body inside this so the wrapper can't drift between them.
///
/// The first-detection latch is intentionally NOT owned here: the two callers
/// latch on different conditions (search pops on the first non-empty scan;
/// verification only latches on a successful match and keeps scanning on a
/// mismatch), so each keeps its own detection handler.
class BarcodeScannerScaffold extends StatelessWidget {
  const BarcodeScannerScaffold({
    super.key,
    required this.onClose,
    required this.child,
  });

  /// Invoked by the AppBar close button. Callers pop with their own result type
  /// (`false` for verification, `null` for search).
  final VoidCallback onClose;

  /// The scanner body — typically the camera view, optionally with extra UI
  /// (manual entry, error text) stacked by the caller.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Scan order tag'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}
