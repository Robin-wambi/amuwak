import 'package:flutter/foundation.dart';

/// A discoverable label printer (typically a Bluetooth thermal printer).
@immutable
class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    this.address,
  });

  /// Stable identifier used to reconnect (MAC address on Android, identifier
  /// UUID on iOS). Persisted so the rider needn't re-pair each shift.
  final String id;

  /// Human-readable name shown in the printer-pick sheet.
  final String name;

  /// Optional transport address when it differs from [id].
  final String? address;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'address': address,
      };

  factory PrinterDevice.fromJson(Map<String, Object?> json) => PrinterDevice(
        id: json['id']! as String,
        name: json['name']! as String,
        address: json['address'] as String?,
      );

  // Identity is the [id] (MAC / iOS identifier). Name and address are display/
  // transport detail and can differ between a live `discover()` result and one
  // rehydrated from storage, so they're excluded from equality.
  @override
  bool operator ==(Object other) => other is PrinterDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PrinterDevice($name, $id)';
}

/// Drives a label printer from raster bitmaps.
///
/// Implementations stay behind this interface so the UI never depends on a
/// specific Bluetooth plugin or command language — the tag is always handed
/// over as a PNG ([printRaster]).
abstract class LabelPrinter {
  /// Bonded/visible printers to choose from.
  Future<List<PrinterDevice>> discover();

  /// Connect to [device]. Idempotent if already connected to it.
  Future<void> connect(PrinterDevice device);

  /// Drop the active connection, if any.
  Future<void> disconnect();

  /// Print the tag bitmap. Throws if no printer is connected.
  Future<void> printRaster(Uint8List pngBytes);

  bool get isConnected;

  /// The currently connected printer, or null.
  PrinterDevice? get connected;
}
