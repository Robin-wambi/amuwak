import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:amuwak_staff/src/orders/proof/tag_pdf.dart';

/// A real PNG of the given pixel size — the rasterised tag [buildTagPdf] wraps.
Uint8List _png({int width = 200, int height = 200}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

void main() {
  group('tagPageFormat', () {
    test('keeps the tag square when the raster is square', () {
      final format = tagPageFormat(400, 400);

      expect(format.height, closeTo(format.width, 0.001));
    });

    test('matches the page to a tall raster so the QR is never stretched', () {
      final format = tagPageFormat(200, 400);

      expect(format.height, closeTo(format.width * 2, 0.001));
    });

    test('falls back to a square page for a zero-width raster', () {
      // Guards a divide-by-zero if a capture ever returns a degenerate image.
      final format = tagPageFormat(0, 400);

      expect(format.width, greaterThan(0));
      expect(format.height, closeTo(format.width, 0.001));
    });
  });

  group('buildTagPdf', () {
    test('produces a PDF document', () async {
      final bytes = await buildTagPdf(_png());

      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('closes the document with an EOF marker', () async {
      final bytes = await buildTagPdf(_png());

      final tail = latin1.decode(bytes.skip(bytes.length - 8).toList());
      expect(tail, contains('%%EOF'));
    });

    test('embeds the raster rather than emitting an empty page', () async {
      // A 400x400 raster carries more image data than a 20x20 one; if the
      // image were dropped both documents would be the same size.
      final small = await buildTagPdf(_png(width: 20, height: 20));
      final large = await buildTagPdf(_png(width: 400, height: 400));

      expect(large.length, greaterThan(small.length));
    });
  });
}
