import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Physical width of a printed bag tag. Matches the common 58mm direct-thermal
/// label stock, so a tag downloaded as a PDF prints at the same size as one
/// sent straight to the label printer.
const double kTagWidthMm = 58;

/// The page size for a tag rasterised at [imageWidth] x [imageHeight] pixels.
///
/// Fixed physical width, height derived from the raster's aspect ratio, so the
/// QR is never stretched — a distorted QR loses the square modules a scanner
/// locks onto. A degenerate raster (either dimension null or zero, which is how
/// the PDF library reports an image it could not measure) falls back to a
/// square page rather than dividing by zero.
PdfPageFormat tagPageFormat(
  int? imageWidth,
  int? imageHeight, {
  double widthMm = kTagWidthMm,
}) {
  final width = widthMm * PdfPageFormat.mm;
  final ratio = (imageWidth == null ||
          imageHeight == null ||
          imageWidth <= 0 ||
          imageHeight <= 0)
      ? 1.0
      : imageHeight / imageWidth;
  return PdfPageFormat(width, width * ratio);
}

/// Wraps an already-rasterised bag tag in a single-page PDF.
///
/// Takes the PNG that [captureTagPng] produces for the thermal printer rather
/// than re-laying-out the tag with PDF widgets: one layout, one source of
/// truth, so the downloaded PDF and the printed label can never drift apart.
///
/// The page carries no margin — [PrintableTag] already draws its own white
/// padding, which is the QR's quiet zone.
Future<Uint8List> buildTagPdf(Uint8List tagPng) async {
  final image = pw.MemoryImage(tagPng);
  final document = pw.Document()
    ..addPage(
      pw.Page(
        pageFormat: tagPageFormat(image.width, image.height),
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Image(image, fit: pw.BoxFit.contain),
      ),
    );
  return document.save();
}
