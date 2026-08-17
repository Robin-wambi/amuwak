import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

/// Thrown when a captured tag can't be turned into a PDF, carrying a
/// rider-readable message instead of leaking a decode failure.
class TagPdfException implements Exception {
  const TagPdfException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Physical width of a printed bag tag. Matches the common 58mm direct-thermal
/// label stock, so a tag downloaded as a PDF prints at the same size as one
/// sent straight to the label printer.
const double kTagWidthMm = 58;

/// A PDF page size in points (1/72 inch), the only unit PDF understands.
class TagPageSize {
  const TagPageSize(this.width, this.height);
  final double width;
  final double height;
}

/// Points per millimetre: 72 points per inch, 25.4 mm per inch.
const double _pointsPerMm = 72 / 25.4;

/// The page size for a tag rasterised at [imageWidth] x [imageHeight] pixels.
///
/// Fixed physical width, height derived from the raster's aspect ratio, so the
/// QR is never stretched — a distorted QR loses the square modules a scanner
/// locks onto. A degenerate raster (either dimension null or zero) falls back
/// to a square page rather than dividing by zero.
TagPageSize tagPageFormat(
  int? imageWidth,
  int? imageHeight, {
  double widthMm = kTagWidthMm,
}) {
  final width = widthMm * _pointsPerMm;
  final degenerate = imageWidth == null ||
      imageHeight == null ||
      imageWidth <= 0 ||
      imageHeight <= 0;
  final ratio = degenerate ? 1.0 : imageHeight / imageWidth;
  return TagPageSize(width, width * ratio);
}

/// Wraps an already-rasterised bag tag in a single-page PDF.
///
/// Takes the PNG that `captureTagPng` produces for the thermal printer rather
/// than re-laying-out the tag, so the downloaded PDF and the printed label can
/// never drift apart. The page carries no margin — `PrintableTag` already draws
/// its own white padding, which is the QR's quiet zone.
///
/// The PDF is emitted directly rather than through the `pdf` package: every
/// published version of that package conflicts with this app's dependencies on
/// the pinned Flutter SDK (it needs either `archive ^3.x` or `vector_math
/// ^2.2.0`, and the SDK pins `vector_math` to 2.1.4). A single page wrapping a
/// single image is a small enough slice of PDF to own outright, and owning it
/// means the toolchain pin and this feature stop fighting.
///
/// The tag is black-on-white, so the raster is reduced to 8-bit greyscale —
/// one byte per pixel instead of three, with no information lost — and the
/// stream is deflated.
Future<Uint8List> buildTagPdf(Uint8List tagPng) async {
  // decodeImage returns null for an unrecognised format but *throws* when the
  // bytes are recognisable enough to start decoding and then turn out to be
  // malformed. Both mean the same thing to the rider.
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(tagPng);
  } catch (e) {
    throw TagPdfException("The tag image couldn't be read: $e");
  }
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const TagPdfException("The tag image couldn't be read.");
  }

  // grayscale() sets r == g == b, so pulling the red channel yields one byte
  // per pixel with no loss for a black-on-white tag.
  final grey = img.grayscale(decoded);
  final pixels = grey.getBytes(order: img.ChannelOrder.red);
  final stream = const ZLibEncoder().encodeBytes(pixels);
  final page = tagPageFormat(decoded.width, decoded.height);

  final w = page.width.toStringAsFixed(2);
  final h = page.height.toStringAsFixed(2);
  // Map the image's unit square onto the whole page.
  final content = 'q $w 0 0 $h 0 0 cm /Im0 Do Q\n';

  final out = BytesBuilder();
  // Byte offset of each object, indexed by object number - 1. The xref table
  // is only valid if these are the real offsets, so they are recorded as the
  // document is written rather than computed afterwards.
  final offsets = <int>[];

  void ascii(String value) => out.add(latin1.encode(value));

  void object(int number, String body) {
    offsets.add(out.length);
    ascii('$number 0 obj\n$body\nendobj\n');
  }

  ascii('%PDF-1.4\n');
  // Four high bytes mark the file as binary so tools don't mangle it as text.
  out.add(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  object(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  object(
    3,
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] '
    '/Resources << /XObject << /Im0 4 0 R >> >> /Contents 5 0 R >>',
  );

  // Object 4 carries binary stream data, so it is written by hand rather than
  // through object().
  offsets.add(out.length);
  ascii('4 0 obj\n'
      '<< /Type /XObject /Subtype /Image '
      '/Width ${decoded.width} /Height ${decoded.height} '
      '/ColorSpace /DeviceGray /BitsPerComponent 8 '
      '/Filter /FlateDecode /Length ${stream.length} >>\n'
      'stream\n');
  out.add(stream);
  ascii('\nendstream\nendobj\n');

  object(5, '<< /Length ${content.length} >>\nstream\n$content endstream');

  final xrefOffset = out.length;
  ascii('xref\n0 ${offsets.length + 1}\n');
  ascii('0000000000 65535 f \n');
  for (final offset in offsets) {
    ascii('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  ascii('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF\n');

  return out.toBytes();
}
