import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../printing/label_printer.dart';
import '../../printing/printer_store.dart';
import 'printable_tag.dart';

/// Requests the Bluetooth permission needed to reach a printer. Returns whether
/// access is granted. Injectable so tests don't hit the platform.
typedef BluetoothPermissionRequester = Future<bool> Function();

/// Default permission gate. On Android 12+ `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN`
/// are runtime-granted; without them the plugin's scan silently returns empty,
/// so we request them up front. On iOS the system prompts on first CoreBluetooth
/// use via the Info.plist usage string, and in tests (host OS) this is a no-op.
Future<bool> requestBluetoothPermissionDefault() async {
  // Web has no BT-print path (and dart:io Platform would throw there); iOS
  // prompts via the Info.plist string on first CoreBluetooth use.
  if (kIsWeb || !Platform.isAndroid) return true;
  final statuses = await [
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
  ].request();
  return statuses.values.every((status) => status.isGranted);
}

/// The printable bag-tag preview plus a "Print tag" action.
///
/// Reused wherever a tag is produced — at pickup (tag the bag) and as a reprint
/// from the order screen. Owns the permission/pick/connect/print orchestration
/// so callers only supply the order code, customer name, and a [LabelPrinter].
/// When [labelPrinter] is null the button is hidden and only the preview shows,
/// so a printerless site still sees the tag to copy/scan by hand.
class TagPrintView extends StatefulWidget {
  const TagPrintView({
    super.key,
    required this.orderCode,
    required this.customerName,
    this.labelPrinter,
    this.printerStore,
    this.captureTag = captureTagPng,
    this.requestBluetoothPermission = requestBluetoothPermissionDefault,
    this.qrSize = 220,
    this.buttonKey = const Key('print_tag'),
  });

  final String orderCode;
  final String customerName;
  final LabelPrinter? labelPrinter;

  /// Remembers the last printer so the rider needn't re-pick it each shift.
  final PrinterStore? printerStore;

  /// Rasterises the printable tag. Injectable so tests skip real PNG encoding.
  final TagCapturer captureTag;

  /// Bluetooth permission gate. Injectable so tests skip the platform.
  final BluetoothPermissionRequester requestBluetoothPermission;

  final double qrSize;

  /// Key on the print button so screens can target their own instance in tests.
  final Key buttonKey;

  @override
  State<TagPrintView> createState() => _TagPrintViewState();
}

class _TagPrintViewState extends State<TagPrintView> {
  bool _printing = false;

  /// Wraps the on-screen [PrintableTag] so [TagCapturer] rasterises exactly what
  /// is shown.
  final GlobalKey _tagBoundaryKey = GlobalKey();

  Future<void> _onPrintTag() async {
    final printer = widget.labelPrinter;
    if (printer == null || _printing) return;
    setState(() => _printing = true);
    try {
      if (!printer.isConnected) {
        if (!await widget.requestBluetoothPermission()) {
          _snack('Bluetooth permission is needed to reach the printer.');
          return;
        }
        if (!await _connectPrinter(printer)) return;
      }
      final bytes = await widget.captureTag(_tagBoundaryKey);
      await printer.printRaster(bytes);
      _snack('Tag sent to printer.');
    } catch (e) {
      _snack('Could not print the tag: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  /// Connect, preferring the remembered printer so the rider skips the picker.
  /// Falls back to the picker if there's no remembered printer or it's
  /// unreachable, and saves whichever printer connects. Returns false if the
  /// rider cancels or none are paired.
  Future<bool> _connectPrinter(LabelPrinter printer) async {
    final remembered = widget.printerStore?.load();
    if (remembered != null) {
      try {
        await printer.connect(remembered);
        return true;
      } catch (_) {
        // Remembered printer unreachable — fall through to the picker.
      }
    }
    final device = await _pickPrinter(printer);
    if (device == null) return false;
    try {
      await printer.connect(device);
    } catch (_) {
      // Distinguish a connection failure from a print failure for the rider.
      _snack('Could not connect to ${device.name}. Is it on and in range?');
      return false;
    }
    try {
      await widget.printerStore?.save(device);
    } catch (_) {
      // Remembering the printer is best-effort; a prefs failure must not abort
      // the print now that we're connected.
    }
    return true;
  }

  /// Ask the rider which paired printer to use. Returns null if they cancel or
  /// none are paired (in which case we point them at the write/scan fallback).
  Future<PrinterDevice?> _pickPrinter(LabelPrinter printer) async {
    final devices = await printer.discover();
    if (!mounted) return null;
    if (devices.isEmpty) {
      _snack(
        'No paired printer found. Pair one in Bluetooth settings, or write '
        'the order # on the bag.',
      );
      return null;
    }
    return showModalBottomSheet<PrinterDevice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose a printer'),
            ),
            for (final device in devices)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(device.name),
                onTap: () => Navigator.pop(context, device),
              ),
          ],
        ),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPrint = widget.labelPrinter != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The on-screen preview IS what prints — captured via _tagBoundaryKey.
        PrintableTag(
          orderCode: widget.orderCode,
          customerName: widget.customerName,
          boundaryKey: _tagBoundaryKey,
          qrSize: widget.qrSize,
        ),
        if (canPrint) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: widget.buttonKey,
            onPressed: _printing ? null : _onPrintTag,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print tag'),
          ),
        ],
      ],
    );
  }
}
