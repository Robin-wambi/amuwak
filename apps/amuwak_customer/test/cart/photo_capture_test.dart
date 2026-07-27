import 'package:amuwak_customer/src/cart/photo_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('caps the longer edge of a landscape photo, keeping aspect ratio', () {
    final target =
        compressTargetForMaxEdge(width: 4000, height: 3000, maxEdge: 1280);
    expect(target.minWidth, 1280);
    expect(target.minHeight, 960);
  });

  test('caps the longer edge of a portrait photo', () {
    final target =
        compressTargetForMaxEdge(width: 3000, height: 4000, maxEdge: 1280);
    expect(target.minWidth, 960);
    expect(target.minHeight, 1280);
  });

  test('a square photo caps both edges', () {
    final target =
        compressTargetForMaxEdge(width: 2000, height: 2000, maxEdge: 1280);
    expect(target.minWidth, 1280);
    expect(target.minHeight, 1280);
  });

  test('uses the same budget as the staff app proof photos', () {
    expect(kCartPhotoMaxEdge, 1280);
    expect(kCartPhotoQuality, 80);
  });
}
