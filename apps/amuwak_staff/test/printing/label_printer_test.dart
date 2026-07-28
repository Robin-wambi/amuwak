import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/printing/label_printer.dart';

void main() {
  group('PrinterDevice', () {
    test('identity is the id — name/address are ignored for equality', () {
      const a = PrinterDevice(id: 'AA:BB', name: 'Printer 1', address: 'x');
      const sameId = PrinterDevice(id: 'AA:BB', name: 'Renamed', address: 'y');
      const otherId = PrinterDevice(id: 'CC:DD', name: 'Printer 1');
      expect(a, equals(sameId));
      expect(a.hashCode, equals(sameId.hashCode));
      expect(a, isNot(equals(otherId)));
    });

    test('toString shows the name and id', () {
      const d = PrinterDevice(id: 'AA:BB', name: 'Front desk');
      expect(d.toString(), 'PrinterDevice(Front desk, AA:BB)');
    });

    test('toJson/fromJson round-trips, including a null address', () {
      const withAddr = PrinterDevice(id: 'AA:BB', name: 'P', address: 'addr');
      const noAddr = PrinterDevice(id: 'CC:DD', name: 'Q');
      expect(PrinterDevice.fromJson(withAddr.toJson()), equals(withAddr));
      final rehydrated = PrinterDevice.fromJson(noAddr.toJson());
      expect(rehydrated, equals(noAddr));
      expect(rehydrated.address, isNull);
    });
  });
}
