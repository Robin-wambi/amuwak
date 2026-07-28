import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bluetooth_label_printer.dart';
import 'label_printer.dart';
import 'printer_store.dart';

/// The resolved [SharedPreferences] instance. Overridden in `main()` after
/// `getInstance()` so the rest of the app can read it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

/// The label printer the app drives, or null where there's no Bluetooth-print
/// path (the web PWA). A single instance holds the live connection across
/// screens; a null printer hides the print/reprint actions. Tests inject a fake
/// via the screen constructors.
final labelPrinterProvider = Provider<LabelPrinter?>(
  (ref) => kIsWeb ? null : BluetoothLabelPrinter(),
);

/// Persists the last-connected printer so the rider needn't re-pick it.
final printerStoreProvider = Provider<PrinterStore>(
  (ref) => PrinterStore(ref.watch(sharedPreferencesProvider)),
);
