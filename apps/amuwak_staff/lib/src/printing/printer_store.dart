import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'label_printer.dart';

/// Remembers the last-connected printer so the rider doesn't re-pick it each
/// shift. Backed by [SharedPreferences].
class PrinterStore {
  PrinterStore(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'printing.last_printer';

  Future<void> save(PrinterDevice device) =>
      _prefs.setString(storageKey, jsonEncode(device.toJson()));

  /// The remembered printer, or null if none is saved or the stored value is
  /// unreadable (e.g. a format change in a past version).
  PrinterDevice? load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return PrinterDevice.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => _prefs.remove(storageKey);
}
