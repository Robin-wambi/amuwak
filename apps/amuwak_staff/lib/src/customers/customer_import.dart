import 'package:amuwak_core/amuwak_core.dart';

import '../data/app_database.dart' show Customer;

/// One customer parsed from an import source (CSV today; device contacts later
/// map to the same shape), before it becomes a [Customer] with an id.
class ParsedCustomerRow {
  const ParsedCustomerRow({
    required this.name,
    required this.phone,
    this.address,
  });

  final String name;
  final String phone;
  final String? address;
}

/// The outcome of parsing an import file: the accepted [rows] plus one
/// human-readable message per rejected line (bad phone / missing name).
class CsvParseResult {
  const CsvParseResult({required this.rows, required this.errors});

  final List<ParsedCustomerRow> rows;
  final List<String> errors;
}

/// A de-duplicated import ready to write: the [Customer]s to upsert, plus counts
/// of what was dropped so the UI can report "imported N, skipped M".
class ImportPlan {
  const ImportPlan({
    required this.toImport,
    required this.duplicatesInFile,
    required this.duplicatesExisting,
  });

  final List<Customer> toImport;
  final int duplicatesInFile;
  final int duplicatesExisting;
}

const _headerKeywords = {'name', 'phone', 'tel', 'telephone', 'mobile', 'address'};

/// Parses a CSV of customers.
///
/// Recognizes an optional header row containing name/phone/address columns (any
/// order, case-insensitive); otherwise treats the columns positionally as
/// name, phone, address. Fully blank lines are skipped. Rows missing a name, or
/// whose phone is not a valid Ugandan national number, are collected in
/// [CsvParseResult.errors] with their 1-based line number and skipped.
CsvParseResult parseCustomersCsv(String text) {
  final table = _parseCsvTable(text);
  if (table.isEmpty) {
    return const CsvParseResult(rows: [], errors: []);
  }

  var startLine = 0;
  var nameIdx = 0, phoneIdx = 1;
  int? addressIdx = 2;

  final header = table.first.map((c) => c.trim().toLowerCase()).toList();
  final looksLikeHeader = header.any(_headerKeywords.contains);
  if (looksLikeHeader) {
    startLine = 1;
    nameIdx = header.indexWhere((c) => c.contains('name'));
    phoneIdx = header
        .indexWhere((c) => c.contains('phone') || c.contains('tel') || c.contains('mobile'));
    addressIdx = header.indexWhere((c) => c.contains('address'));
    if (addressIdx < 0) addressIdx = null;
  }

  final rows = <ParsedCustomerRow>[];
  final errors = <String>[];

  for (var i = startLine; i < table.length; i++) {
    final line = i + 1; // 1-based, counting the header
    final cells = table[i];
    String cell(int? idx) =>
        (idx != null && idx >= 0 && idx < cells.length) ? cells[idx].trim() : '';

    final name = cell(nameIdx);
    final phone = cell(phoneIdx);
    final address = cell(addressIdx);

    // A wholly empty line (e.g. a trailing blank) is not an error.
    if (name.isEmpty && phone.isEmpty && address.isEmpty) continue;

    if (name.isEmpty) {
      errors.add('Line $line: missing name.');
      continue;
    }
    if (ugandaNationalDigits(phone).length != 9) {
      errors.add('Line $line: invalid phone "$phone".');
      continue;
    }
    rows.add(ParsedCustomerRow(
      name: name,
      phone: phone,
      address: address.isEmpty ? null : address,
    ));
  }

  return CsvParseResult(rows: rows, errors: errors);
}

/// De-dupes [rows] against [existing] customers and against each other (by
/// normalized national phone number), then materializes [Customer]s for the
/// survivors using [idGenerator] and [now].
ImportPlan planCustomerImport(
  List<ParsedCustomerRow> rows,
  List<Customer> existing, {
  required String Function() idGenerator,
  required DateTime Function() now,
}) {
  final existingNumbers = {
    for (final c in existing) ugandaNationalDigits(c.phone),
  };
  final seen = <String>{};
  final toImport = <Customer>[];
  var duplicatesInFile = 0;
  var duplicatesExisting = 0;

  for (final row in rows) {
    final national = ugandaNationalDigits(row.phone);
    if (existingNumbers.contains(national)) {
      duplicatesExisting++;
      continue;
    }
    if (!seen.add(national)) {
      duplicatesInFile++;
      continue;
    }
    final stamp = now();
    toImport.add(Customer(
      id: idGenerator(),
      name: row.name,
      phone: row.phone,
      address: row.address,
      notes: null,
      customRatePerKgUgx: null,
      createdAt: stamp,
      updatedAt: stamp,
      deletedAt: null,
    ));
  }

  return ImportPlan(
    toImport: toImport,
    duplicatesInFile: duplicatesInFile,
    duplicatesExisting: duplicatesExisting,
  );
}

/// Minimal RFC-4180-ish CSV reader: comma-delimited, `"`-quoted fields (with
/// `""` as an escaped quote), CRLF or LF row breaks. Enough for the exports a
/// laundry produces from a spreadsheet, without pulling in a package.
List<List<String>> _parseCsvTable(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var inQuotes = false;

  void endField() {
    row.add(field.toString());
    field = StringBuffer();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
      continue;
    }
    switch (ch) {
      case '"':
        inQuotes = true;
      case ',':
        endField();
      case '\r':
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      case '\n':
        endRow();
      default:
        field.write(ch);
    }
  }

  // Flush the trailing field/row unless it is an artifact of a final newline
  // (which leaves an empty single-field row we should not emit).
  if (field.isNotEmpty || row.isNotEmpty) {
    endRow();
  }

  return rows;
}
