import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../proof_event.dart';
import 'proof_photo_storage.dart';

/// Computes the `minWidth` / `minHeight` pair to pass to
/// `FlutterImageCompress.compressWithList` so that the LONGER edge of the
/// result is at most [maxEdge] pixels, preserving aspect ratio.
({int minWidth, int minHeight}) compressTargetForMaxEdge({
  required int width,
  required int height,
  required int maxEdge,
}) {
  if (width >= height) {
    return (
      minWidth: maxEdge,
      minHeight: (maxEdge * height / width).round(),
    );
  }
  return (
    minWidth: (maxEdge * width / height).round(),
    minHeight: maxEdge,
  );
}

typedef PhotoCompressor = Future<Uint8List> Function(Uint8List bytes);

class FileProofPhotoStorage implements ProofPhotoStorage {
  FileProofPhotoStorage({
    required this.baseDir,
    required this.compressor,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Directory baseDir;
  final PhotoCompressor compressor;
  final DateTime Function() _clock;

  @override
  Future<String> save({
    required String orderId,
    required ProofEventType type,
    required int index,
    required List<int> bytes,
  }) async {
    final orderDir = Directory(
      '${baseDir.path}${Platform.pathSeparator}proofs${Platform.pathSeparator}$orderId',
    );
    if (!await orderDir.exists()) {
      await orderDir.create(recursive: true);
    }
    final compressed = await compressor(Uint8List.fromList(bytes));
    final filename =
        '${type.name}_${_clock().millisecondsSinceEpoch}_$index.jpg';
    final file = File('${orderDir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(compressed);
    return file.path;
  }
}

/// Production factory: resolves the app documents directory via path_provider
/// and uses flutter_image_compress to shrink images so the longer edge is
/// capped at 1280 pixels (JPEG quality 80). Native targets only.
Future<FileProofPhotoStorage> createDefaultProofPhotoStorage() async {
  final dir = await getApplicationDocumentsDirectory();
  return FileProofPhotoStorage(
    baseDir: dir,
    compressor: (bytes) async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final target = compressTargetForMaxEdge(
        width: image.width,
        height: image.height,
        maxEdge: 1280,
      );
      image.dispose();
      codec.dispose();
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: target.minWidth,
        minHeight: target.minHeight,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      return result;
    },
  );
}
