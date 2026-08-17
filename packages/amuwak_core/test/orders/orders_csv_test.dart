import 'dart:convert';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

LaundryOrder _order({
  String orderId = 'o1',
  String? orderCode = 'AMW-2026-0001',
  String customerName = 'Ada',
  String phone = '0700000000',
  String address = 'Kira',
  String notes = '',
  OrderStatus status = OrderStatus.pendingPickup,
  ServiceType serviceType = ServiceType.washAndIron,
  String fulfillmentMethod = 'delivery',
  int itemCount = 3,
  double? estimatedWeightKg,
  double? finalWeightKg,
  int totalUgx = 0,
  int paymentAmountUgx = 0,
  DateTime? scheduledFor,
  DateTime? expectedCollectionAt,
}) =>
    LaundryOrder(
      orderId: orderId,
      orderCode: orderCode,
      customerName: customerName,
      phone: phone,
      address: address,
      notes: notes,
      status: status,
      serviceType: serviceType,
      fulfillmentMethod: fulfillmentMethod,
      itemCount: itemCount,
      timeLabel: '',
      estimatedWeightKg: estimatedWeightKg,
      finalWeightKg: finalWeightKg,
      totalUgx: totalUgx,
      paymentAmountUgx: paymentAmountUgx,
      scheduledFor: scheduledFor,
      expectedCollectionAt: expectedCollectionAt,
    );

/// The data rows of [csv], excluding the header.
List<String> _dataRows(String csv) =>
    const LineSplitter().convert(csv).skip(1).toList();

/// The single data row of a one-order export, split on unquoted commas is
/// deliberately NOT done here — tests assert on the raw line so quoting is
/// visible in the expectation.
String _onlyRow(String csv) => _dataRows(csv).single;

void main() {
  group('ordersToCsv', () {
    test('writes the header row even when there are no orders', () {
      final csv = ordersToCsv(const []);

      expect(const LineSplitter().convert(csv), hasLength(1));
      expect(csv, startsWith('Order Code,Customer,Phone,Status,'));
    });

    test('writes one row per order', () {
      final csv = ordersToCsv([
        _order(orderId: 'a', orderCode: 'AMW-2026-0001'),
        _order(orderId: 'b', orderCode: 'AMW-2026-0002'),
      ]);

      final rows = _dataRows(csv);
      expect(rows, hasLength(2));
      expect(rows[0], startsWith('AMW-2026-0001,'));
      expect(rows[1], startsWith('AMW-2026-0002,'));
    });

    test('reports an unsynced order as Pending sync, not its raw UUID', () {
      // orderCode defaults to orderId while an offline order awaits its
      // server-minted code; that UUID must never read as an order number.
      final csv = ordersToCsv([_order(orderId: 'uuid-1', orderCode: null)]);

      expect(_onlyRow(csv), startsWith('Pending sync,'));
      expect(csv, isNot(contains('uuid-1')));
    });

    test('quotes a field containing a comma', () {
      final csv = ordersToCsv([_order(address: 'Plot 5, Kira Road')]);

      expect(_onlyRow(csv), contains('"Plot 5, Kira Road"'));
    });

    test('escapes a double quote by doubling it', () {
      final csv = ordersToCsv([_order(customerName: 'Ada "Queen" N')]);

      expect(_onlyRow(csv), contains('"Ada ""Queen"" N"'));
    });

    test('keeps a newline inside a quoted field', () {
      final csv = ordersToCsv([_order(notes: 'line one\nline two')]);

      expect(csv, contains('"line one\nline two"'));
    });

    test('neutralises a formula so Excel does not execute it', () {
      // A rider's note starting with = + - or @ is executed as a formula when
      // the CSV is opened in Excel. Prefix with an apostrophe so it stays text.
      for (final dangerous in ['=cmd()', '+1+1', '-1+1', '@SUM(A1)']) {
        final csv = ordersToCsv([_order(notes: dangerous)]);

        expect(_onlyRow(csv), contains("\"'$dangerous\""),
            reason: 'should neutralise $dangerous');
      }
    });

    test('derives outstanding from total minus collected', () {
      final csv = ordersToCsv([_order(totalUgx: 50000, paymentAmountUgx: 20000)]);

      final row = _onlyRow(csv);
      expect(row, contains('50000,20000,30000'));
    });

    test('leaves optional weights and dates blank rather than writing null', () {
      final csv = ordersToCsv([_order()]);

      expect(csv, isNot(contains('null')));
      // Trailing empty notes field means the row ends with a comma.
      expect(_onlyRow(csv), contains(',,'));
    });

    test('formats dates as local yyyy-MM-dd HH:mm', () {
      final csv = ordersToCsv([
        _order(
          scheduledFor: DateTime(2026, 8, 16, 9, 5),
          expectedCollectionAt: DateTime(2026, 8, 18, 14, 30),
        ),
      ]);

      final row = _onlyRow(csv);
      expect(row, contains('2026-08-16 09:05'));
      expect(row, contains('2026-08-18 14:30'));
    });

    test('writes the human labels for status and service', () {
      final csv = ordersToCsv([
        _order(
          status: OrderStatus.readyForDelivery,
          serviceType: ServiceType.washOnly,
        ),
      ]);

      final row = _onlyRow(csv);
      expect(row, contains(OrderStatus.readyForDelivery.label));
      expect(row, contains(ServiceType.washOnly.label));
    });

    test('uses CRLF line endings per RFC 4180', () {
      final csv = ordersToCsv([_order()]);

      expect(csv, contains('\r\n'));
    });
  });

  group('ordersCsvBytes', () {
    test('prefixes a UTF-8 BOM so Excel renders non-ASCII names', () {
      final bytes = ordersCsvBytes([_order(customerName: 'Nakato Ssebbaale')]);

      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    });

    test('encodes the body as UTF-8', () {
      final bytes = ordersCsvBytes([_order(customerName: 'Zoë')]);

      expect(utf8.decode(bytes.skip(3).toList()), contains('Zoë'));
    });
  });
}
