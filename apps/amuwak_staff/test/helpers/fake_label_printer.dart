import 'dart:typed_data';

import 'package:amuwak_staff/src/printing/label_printer.dart';

/// In-memory [LabelPrinter] for widget tests. Records what was printed and lets
/// a test pre-seed discoverable devices and the initial connection. Lives in
/// `test/` so it never ships in a release build.
class FakeLabelPrinter implements LabelPrinter {
  FakeLabelPrinter({
    List<PrinterDevice> devices = const [],
    PrinterDevice? connected,
    this.connectThrows = false,
    this.connectFailingIds = const {},
    this.printThrows,
  })  : _devices = devices,
        _connected = connected;

  final List<PrinterDevice> _devices;
  PrinterDevice? _connected;

  /// When true, [connect] throws for any device.
  final bool connectThrows;

  /// Device ids whose [connect] throws — e.g. a remembered printer that's gone.
  final Set<String> connectFailingIds;

  /// When set, [printRaster] throws this to exercise the error path.
  final Object? printThrows;

  final List<Uint8List> printed = <Uint8List>[];
  final List<PrinterDevice> connectCalls = <PrinterDevice>[];
  int discoverCalls = 0;

  @override
  PrinterDevice? get connected => _connected;

  @override
  bool get isConnected => _connected != null;

  @override
  Future<List<PrinterDevice>> discover() async {
    discoverCalls++;
    return _devices;
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    connectCalls.add(device);
    if (connectThrows || connectFailingIds.contains(device.id)) {
      throw Exception('connect failed');
    }
    _connected = device;
  }

  @override
  Future<void> disconnect() async {
    _connected = null;
  }

  @override
  Future<void> printRaster(Uint8List pngBytes) async {
    if (printThrows != null) {
      throw printThrows!;
    }
    printed.add(pngBytes);
  }
}
