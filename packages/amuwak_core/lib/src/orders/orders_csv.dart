import 'dart:convert';
import 'dart:typed_data';

import 'order.dart';

/// Renders a list of orders as an RFC 4180 CSV document.
///
/// Pure and Drift-free so both apps can call it and it can be unit-tested
/// without a widget tree: the platform-specific "save/share this file" step is
/// the caller's job.
///
/// House rules encoded here:
/// - Money is integer UGX with no separators, so a spreadsheet reads the cells
///   as numbers rather than text.
/// - `outstanding` is DERIVED from total minus collected (never stored), the
///   same rule the app renders by. See [LaundryOrder.outstandingUgx].
/// - An order still awaiting its server-minted code exports as "Pending sync"
///   rather than leaking its placeholder UUID, matching
///   [LaundryOrder.referenceLabel].
String ordersToCsv(List<LaundryOrder> orders) {
  final buffer = StringBuffer()..write(_row(_header));
  for (final order in orders) {
    buffer.write(_row(_cells(order)));
  }
  return buffer.toString();
}

/// [ordersToCsv] encoded for writing to a file or a share sheet.
///
/// Prefixed with a UTF-8 byte-order mark: without it Excel decodes the file as
/// the system codepage and mangles any non-ASCII customer name.
Uint8List ordersCsvBytes(List<LaundryOrder> orders) => Uint8List.fromList([
      ..._utf8Bom,
      ...utf8.encode(ordersToCsv(orders)),
    ]);

const _utf8Bom = [0xEF, 0xBB, 0xBF];

const _header = [
  'Order Code',
  'Customer',
  'Phone',
  'Status',
  'Service',
  'Fulfillment',
  'Items',
  'Estimated kg',
  'Final kg',
  'Total UGX',
  'Paid UGX',
  'Outstanding UGX',
  'Scheduled For',
  'Expected Collection',
  'Address',
  'Notes',
];

List<String> _cells(LaundryOrder order) => [
      order.referenceLabel,
      order.customerName,
      order.phone,
      order.status.label,
      order.serviceType.label,
      order.fulfillmentMethod,
      '${order.itemCount}',
      _number(order.estimatedWeightKg),
      _number(order.finalWeightKg),
      '${order.totalUgx}',
      '${order.paymentAmountUgx}',
      '${order.outstandingUgx}',
      _dateTime(order.scheduledFor),
      _dateTime(order.expectedCollectionAt),
      order.address,
      order.notes,
    ];

String _row(List<String> cells) =>
    '${cells.map(_escape).join(',')}\r\n';

/// Empty for a null weight — a blank cell reads as "not recorded", where the
/// string "null" would read as data.
String _number(double? value) => value == null ? '' : '$value';

/// Local `yyyy-MM-dd HH:mm`, matching what staff see in the app. Blank when
/// unset. Seconds are dropped: no laundry decision turns on them, and the
/// shorter form stays readable in a spreadsheet column.
String _dateTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final date = '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

/// Characters that make a spreadsheet treat a cell as a formula rather than
/// text. Order notes and addresses are free text typed by riders, so a cell can
/// legitimately begin with one of these.
const _formulaTriggers = {'=', '+', '-', '@'};

/// Quotes and escapes one cell.
///
/// Two separate concerns, both required:
/// 1. RFC 4180 — a cell containing a comma, quote, CR or LF must be wrapped in
///    double quotes, and any embedded quote doubled.
/// 2. CSV injection — Excel and Sheets execute a cell beginning with = + - or @
///    as a formula, which turns a rider's note into code on the accountant's
///    machine. Prefixing with an apostrophe forces it back to text; the
///    apostrophe is consumed by the spreadsheet on display.
String _escape(String value) {
  var cell = value;
  final neutralised = cell.isNotEmpty && _formulaTriggers.contains(cell[0]);
  if (neutralised) cell = "'$cell";
  // A neutralised cell is always quoted so the guarding apostrophe is
  // unambiguously part of the value and no downstream parser can drop it.
  final mustQuote = neutralised ||
      cell.contains(',') ||
      cell.contains('"') ||
      cell.contains('\n') ||
      cell.contains('\r');
  if (!mustQuote) return cell;
  return '"${cell.replaceAll('"', '""')}"';
}
