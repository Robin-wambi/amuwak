import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_camera_view.dart';

void main() {
  testWidgets('FakeCameraView calls onDetected with scannedValue when tapped',
      (tester) async {
    String? detected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FakeCameraView(
            scannedValue: 'AMW-0421',
            onDetected: (value) => detected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Simulate scan'));
    await tester.pump();

    expect(detected, equals('AMW-0421'));
  });
}
