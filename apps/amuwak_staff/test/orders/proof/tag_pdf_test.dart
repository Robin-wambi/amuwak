import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:amuwak_staff/src/orders/proof/tag_pdf.dart';

/// A real PNG of the given pixel size — the rasterised tag [buildTagPdf] wraps.
Uint8List _png({int width = 200, int height = 200}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

/// PDF syntax is Latin-1 outside stream data, so the structure can be read back
/// as text even though the file as a whole is binary.
String _text(Uint8List bytes) => latin1.decode(bytes, allowInvalid: true);

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

    test('converts the tag width from millimetres to PDF points', () {
      // A PDF point is 1/72 inch; 58mm is the label stock width.
      final format = tagPageFormat(100, 100, widthMm: 25.4);

      expect(format.width, closeTo(72, 0.001));
    });

    test('falls back to a square page for a degenerate raster', () {
      for (final size in [(0, 400), (400, 0), (null, 400), (400, null)]) {
        final format = tagPageFormat(size.$1, size.$2);

        expect(format.width, greaterThan(0));
        expect(format.height, closeTo(format.width, 0.001),
            reason: 'should square up for $size');
      }
    });
  });

  group('buildTagPdf', () {
    test('produces a PDF document', () async {
      final bytes = await buildTagPdf(_png());

      expect(_text(bytes).substring(0, 5), '%PDF-');
    });

    test('closes the document with an EOF marker', () async {
      final bytes = await buildTagPdf(_png());

      expect(_text(bytes).trimRight(), endsWith('%%EOF'));
    });

    test('startxref points at the real byte offset of the xref table', () async {
      // The classic hand-rolled-PDF bug: a stale offset makes the file
      // unopenable in strict readers even though it looks fine as text.
      final bytes = await buildTagPdf(_png());
      final text = _text(bytes);

      final marker = text.lastIndexOf('startxref');
      final offset = int.parse(
        text.substring(marker + 'startxref'.length).trim().split('\n').first,
      );

      expect(_text(Uint8List.sublistView(bytes, offset, offset + 4)), 'xref');
    });

    test('declares one page', () async {
      final bytes = await buildTagPdf(_png());

      expect(_text(bytes), contains('/Count 1'));
    });

    test('sizes the MediaBox to the computed page format', () async {
      final bytes = await buildTagPdf(_png(width: 200, height: 400));
      final format = tagPageFormat(200, 400);

      expect(
        _text(bytes),
        contains('/MediaBox [0 0 ${format.width.toStringAsFixed(2)} '
            '${format.height.toStringAsFixed(2)}]'),
      );
    });

    test('declares the image at the raster\'s pixel dimensions', () async {
      final bytes = await buildTagPdf(_png(width: 320, height: 480));
      final text = _text(bytes);

      expect(text, contains('/Width 320'));
      expect(text, contains('/Height 480'));
    });

    test('compresses the image stream', () async {
      final bytes = await buildTagPdf(_png(width: 400, height: 400));

      expect(_text(bytes), contains('/Filter /FlateDecode'));
      // 400x400 greyscale is 160,000 raw bytes; a blank tag must compress far
      // below that or the stream is not actually deflated.
      expect(bytes.length, lessThan(160000));
    });

    test('embeds the raster rather than emitting an empty page', () async {
      final small = await buildTagPdf(_png(width: 20, height: 20));
      final large = await buildTagPdf(_png(width: 400, height: 400));

      expect(large.length, greaterThan(small.length));
    });

    test('rejects bytes that are not a decodable image', () async {
      expect(
        () => buildTagPdf(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<TagPdfException>()),
      );
    });
  });
}
