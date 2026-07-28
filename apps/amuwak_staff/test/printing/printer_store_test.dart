import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amuwak_staff/src/printing/label_printer.dart';
import 'package:amuwak_staff/src/printing/printer_store.dart';

void main() {
  group('PrinterDevice', () {
    test('equality is by id — name/address are display detail', () {
      // Same MAC from a live discover() vs rehydrated from storage (where
      // address may be null and name may differ) must still be the same device.
      const live = PrinterDevice(id: '00:11:22', name: 'Munbyn M2', address: '00:11:22');
      const stored = PrinterDevice(id: '00:11:22', name: 'Munbyn');
      expect(live, equals(stored));
      expect(live.hashCode, equals(stored.hashCode));

      const other = PrinterDevice(id: 'AA:BB:CC', name: 'Munbyn M2');
      expect(live, isNot(equals(other)));
    });

    test('round-trips through JSON', () {
      const device = PrinterDevice(id: '00:11:22', name: 'Munbyn M2', address: 'A1');
      expect(PrinterDevice.fromJson(device.toJson()), equals(device));
    });
  });

  group('PrinterStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<PrinterStore> store() async =>
        PrinterStore(await SharedPreferences.getInstance());

    test('load returns null before any printer is saved', () async {
      expect((await store()).load(), isNull);
    });

    test('save then load returns the same printer', () async {
      final s = await store();
      const device = PrinterDevice(id: 'AB:CD', name: 'Phomemo', address: 'z');
      await s.save(device);
      expect(s.load(), equals(device));
    });

    test('clear removes the remembered printer', () async {
      final s = await store();
      await s.save(const PrinterDevice(id: 'AB:CD', name: 'Phomemo'));
      await s.clear();
      expect(s.load(), isNull);
    });

    test('load tolerates a corrupt stored value and returns null', () async {
      SharedPreferences.setMockInitialValues({
        PrinterStore.storageKey: 'not-json',
      });
      expect((await store()).load(), isNull);
    });
  });
}
