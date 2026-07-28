import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'label_printer.dart';

/// Thrown when a printer operation fails, carrying a rider-readable message.
class PrinterException implements Exception {
  PrinterException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// [LabelPrinter] backed by a Bluetooth ESC/POS thermal printer
/// (Munbyn/Phomemo/Rollo class hardware) via `print_bluetooth_thermal`.
///
/// The tag arrives as a PNG; we decode it, scale it to the printer's dot width,
/// and emit ESC/POS raster bytes with `esc_pos_utils_plus`. Keeping every
/// vendor detail in here means the UI only ever deals in PNG + [PrinterDevice].
///
/// NOTE: This path can only be verified against real hardware — it drives
/// platform Bluetooth channels. Covered by manual verification, not unit tests.
class BluetoothLabelPrinter implements LabelPrinter {
  BluetoothLabelPrinter({this.paperSize = PaperSize.mm58});

  final PaperSize paperSize;

  PrinterDevice? _connected;

  /// Printable dot width for the paper size (1 dot = 1px in the raster).
  int get _dotWidth => switch (paperSize) {
        PaperSize.mm80 => 576,
        PaperSize.mm72 => 512,
        _ => 384,
      };

  @override
  PrinterDevice? get connected => _connected;

  @override
  bool get isConnected => _connected != null;

  @override
  Future<List<PrinterDevice>> discover() async {
    final paired = await PrintBluetoothThermal.pairedBluetooths;
    return [
      for (final b in paired)
        PrinterDevice(id: b.macAdress, name: b.name, address: b.macAdress),
    ];
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    // connectionStatus (like disconnect below) is a static getter on the
    // plugin, not a method — the missing () is intentional.
    if (_connected == device && await PrintBluetoothThermal.connectionStatus) {
      return;
    }
    final ok =
        await PrintBluetoothThermal.connect(macPrinterAddress: device.id);
    if (!ok) {
      throw PrinterException('Could not connect to ${device.name}.');
    }
    _connected = device;
  }

  @override
  Future<void> disconnect() async {
    // `disconnect` is a static getter on the plugin (returns Future<bool>), not
    // a method — the missing () is intentional.
    await PrintBluetoothThermal.disconnect;
    _connected = null;
  }

  @override
  Future<void> printRaster(Uint8List pngBytes) async {
    if (!isConnected) {
      throw PrinterException('No printer connected.');
    }

    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw PrinterException('Could not read the tag image.');
    }
    // Scale to the head width so the QR fills the label and stays square.
    // Every _dotWidth (384/512/576) is a multiple of 8 — keep it that way:
    // esc_pos_utils_plus's raster encoder has a broken non-multiple-of-8 width
    // path (it zero-fills the buffer), and resizing to a multiple of 8 sidesteps
    // it entirely.
    final scaled = decoded.width == _dotWidth
        ? decoded
        : img.copyResize(decoded, width: _dotWidth);

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final bytes = <int>[
      ...generator.imageRaster(scaled),
      // Feed past the gap so the next label starts clean. No cut: direct-thermal
      // label stock is gap-fed and tears at the perforation.
      ...generator.feed(3),
    ];

    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      // The link is likely dead (out of range / powered off). Drop it so the
      // next print re-enters the connect flow instead of retrying a dead socket.
      _connected = null;
      throw PrinterException(
        'The printer rejected the tag. Check paper and power, then retry.',
      );
    }
  }
}
