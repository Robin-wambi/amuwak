import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/shared/file_share.dart';

void main() {
  group('filenameSlug', () {
    test('lowercases and collapses each non-alphanumeric run to one dash', () {
      expect(filenameSlug('Completed today'), 'completed-today');
      expect(filenameSlug('Ready  for   delivery'), 'ready-for-delivery');
      expect(filenameSlug('Orders (all) / 2026'), 'orders-all-2026');
    });

    test('strips leading and trailing dashes', () {
      // A label that starts or ends with punctuation would otherwise produce
      // `-pending-work-`, and a leading dash reads as a flag to some shells.
      expect(filenameSlug('  Pending work  '), 'pending-work');
      expect(filenameSlug('!Overdue!'), 'overdue');
    });

    test('falls back to "export" when no alphanumerics survive', () {
      // Every character collapses to one dash, which is then stripped to the
      // empty string — an extensionless `.csv` file must not be produced.
      expect(filenameSlug('!!!'), 'export');
      expect(filenameSlug('   '), 'export');
      expect(filenameSlug(''), 'export');
    });

    test('drops non-ASCII rather than passing it through', () {
      // Only the intersection safe on Windows, Android and iOS is kept, so a
      // non-ASCII customer name collapses to dashes instead of surviving.
      expect(filenameSlug('Müller'), 'm-ller');
      expect(filenameSlug('日本語'), 'export');
    });
  });

  group('filenameDate', () {
    test('zero-pads month and day so exports sort chronologically', () {
      expect(filenameDate(DateTime(2026, 6, 11)), '2026-06-11');
      expect(filenameDate(DateTime(2026, 12, 5)), '2026-12-05');
    });

    test('ignores the time component', () {
      expect(filenameDate(DateTime(2026, 6, 11, 23, 59, 59)), '2026-06-11');
    });
  });
}
