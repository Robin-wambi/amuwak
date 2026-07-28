import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrDisplayWidget extends StatelessWidget {
  const QrDisplayWidget({
    super.key,
    required this.data,
    this.size = 240,
    this.errorCorrectionLevel = QrErrorCorrectLevel.H,
  });

  final String data;
  final double size;

  /// Reed-Solomon recovery level. Defaults to High (~30%) — DENSO WAVE
  /// recommends Q or H for codes that get dirty or creased, which matches a
  /// label riding on a damp laundry bag until it's scanned at delivery.
  final int errorCorrectionLevel;

  /// Quiet-zone padding around the QR modules. Gives scanners a margin to lock
  /// onto and keeps the text fallback clear of the tag edge.
  static const double _padding = 16;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      errorCorrectionLevel: errorCorrectionLevel,
      padding: const EdgeInsets.all(_padding),
      gapless: true,
      semanticsLabel: 'QR code for order $data',
      errorStateBuilder: (context, error) => _buildFallback(context, error),
    );
  }

  Widget _buildFallback(BuildContext context, Object? error) {
    // No crash reporter is wired up yet, so surface the failure to the console
    // instead of swallowing it silently. Forward `error` to a reporter
    // (e.g. FirebaseCrashlytics.instance.recordError) here once one is added.
    debugPrint('QrDisplayWidget failed to render order $data: $error');
    return SizedBox(
      width: size,
      height: size,
      // Match the QR's white background so the fallback code stays readable
      // on a dark scaffold.
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Center(
            // Scale the code down to fit so even a long order code stays
            // inside the tag box instead of overflowing it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
