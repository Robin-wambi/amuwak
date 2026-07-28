import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/orders/proof/proof_photo_storage.dart';
import 'package:amuwak_staff/src/orders/proof/proof_photo_storage_io.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';

void main() {
  group('InMemoryProofPhotoStorage', () {
    test('save returns a unique-looking path that encodes order, type, index',
        () async {
      final storage = InMemoryProofPhotoStorage();

      final path = await storage.save(
        orderId: 'AMW-0421',
        type: ProofEventType.pickup,
        index: 0,
        bytes: const [1, 2, 3],
      );

      expect(path, contains('AMW-0421'));
      expect(path, contains('pickup'));
      expect(path, contains('0'));
    });

    test('save retains the bytes and path in savedPhotos', () async {
      final storage = InMemoryProofPhotoStorage();

      final path = await storage.save(
        orderId: 'AMW-1',
        type: ProofEventType.delivery,
        index: 2,
        bytes: const [9, 8, 7],
      );

      expect(storage.savedPhotos, hasLength(1));
      expect(storage.savedPhotos.single.path, equals(path));
      expect(storage.savedPhotos.single.bytes, equals(const [9, 8, 7]));
    });
  });

  group('compressTargetForMaxEdge', () {
    test('landscape source: longer edge becomes maxEdge', () {
      final target = compressTargetForMaxEdge(
        width: 4000,
        height: 3000,
        maxEdge: 1280,
      );
      expect(target.minWidth, equals(1280));
      expect(target.minHeight, equals(960));
    });

    test('portrait source: longer edge becomes maxEdge', () {
      final target = compressTargetForMaxEdge(
        width: 3000,
        height: 4000,
        maxEdge: 1280,
      );
      expect(target.minWidth, equals(960));
      expect(target.minHeight, equals(1280));
    });

    test('square source: both dimensions equal maxEdge', () {
      final target = compressTargetForMaxEdge(
        width: 2000,
        height: 2000,
        maxEdge: 1280,
      );
      expect(target.minWidth, equals(1280));
      expect(target.minHeight, equals(1280));
    });

    test('preserves aspect ratio for narrow portrait', () {
      final target = compressTargetForMaxEdge(
        width: 1080,
        height: 1920,
        maxEdge: 1280,
      );
      expect(target.minHeight, equals(1280));
      expect(target.minWidth, equals(720));
    });
  });

  group('FileProofPhotoStorage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('proof_photo_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<Uint8List> identityCompressor(Uint8List bytes) async => bytes;

    test('save writes a jpg under <baseDir>/proofs/<orderId>/', () async {
      final fixedClock = DateTime(2026, 5, 12, 9, 42, 0).millisecondsSinceEpoch;
      final storage = FileProofPhotoStorage(
        baseDir: tempDir,
        compressor: identityCompressor,
        clock: () => DateTime.fromMillisecondsSinceEpoch(fixedClock),
      );

      final path = await storage.save(
        orderId: 'AMW-1',
        type: ProofEventType.pickup,
        index: 0,
        bytes: const [1, 2, 3, 4],
      );

      final file = File(path);
      expect(await file.exists(), isTrue);
      expect(path, contains('proofs${Platform.pathSeparator}AMW-1'));
      expect(path, endsWith('pickup_${fixedClock}_0.jpg'));
      expect(await file.readAsBytes(), equals(const [1, 2, 3, 4]));
    });

    test('save creates the order directory if missing', () async {
      final storage = FileProofPhotoStorage(
        baseDir: tempDir,
        compressor: identityCompressor,
      );

      final orderDir =
          Directory('${tempDir.path}/proofs/NEW-ORDER');
      expect(await orderDir.exists(), isFalse);

      await storage.save(
        orderId: 'NEW-ORDER',
        type: ProofEventType.delivery,
        index: 1,
        bytes: const [9, 9, 9],
      );

      expect(await orderDir.exists(), isTrue);
    });

    test('save runs bytes through the compressor before writing', () async {
      var compressorCalled = false;
      Future<Uint8List> spyCompressor(Uint8List bytes) async {
        compressorCalled = true;
        return Uint8List.fromList(bytes.reversed.toList());
      }

      final storage = FileProofPhotoStorage(
        baseDir: tempDir,
        compressor: spyCompressor,
      );

      final path = await storage.save(
        orderId: 'AMW-2',
        type: ProofEventType.pickup,
        index: 0,
        bytes: const [1, 2, 3],
      );

      expect(compressorCalled, isTrue);
      expect(await File(path).readAsBytes(), equals(const [3, 2, 1]));
    });
  });
}
