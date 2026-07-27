import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Longest edge / JPEG quality a cart photo is shrunk to before it is stored and
/// uploaded — the same budget the staff app's proof photos use.
const kCartPhotoMaxEdge = 1280;
const kCartPhotoQuality = 80;

/// Picks a photo and returns it compressed, or null if the picker was dismissed.
typedef CartPhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// `minWidth`/`minHeight` for `FlutterImageCompress` such that the LONGER edge
/// of the result is at most [maxEdge], preserving aspect ratio. (Mirrors the
/// staff app's `compressTargetForMaxEdge`.)
({int minWidth, int minHeight}) compressTargetForMaxEdge({
  required int width,
  required int height,
  required int maxEdge,
}) {
  if (width >= height) {
    return (minWidth: maxEdge, minHeight: (maxEdge * height / width).round());
  }
  return (minWidth: (maxEdge * width / height).round(), minHeight: maxEdge);
}

/// Shrinks a captured photo to [kCartPhotoMaxEdge] on its longest edge as JPEG.
/// A phone photo is several MB — far too much to hold in the local DB and push
/// over a Ugandan mobile connection.
Future<Uint8List> compressCartPhoto(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final target = compressTargetForMaxEdge(
    width: image.width,
    height: image.height,
    maxEdge: kCartPhotoMaxEdge,
  );
  image.dispose();
  codec.dispose();
  return FlutterImageCompress.compressWithList(
    bytes,
    minWidth: target.minWidth,
    minHeight: target.minHeight,
    quality: kCartPhotoQuality,
    format: CompressFormat.jpeg,
  );
}

/// The production picker: camera or gallery via `image_picker`, then compressed.
/// A provider so widget tests can inject a canned photo instead of a plugin.
final cartPhotoPickerProvider = Provider<CartPhotoPicker>((ref) {
  final picker = ImagePicker();
  return (source) async {
    final file = await picker.pickImage(source: source);
    if (file == null) return null;
    return compressCartPhoto(await file.readAsBytes());
  };
});
