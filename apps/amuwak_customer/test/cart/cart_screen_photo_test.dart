import 'dart:convert';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/auth/customer_session.dart';
import 'package:amuwak_customer/src/cart/cart_screen.dart';
import 'package:amuwak_customer/src/cart/photo_capture.dart';
import 'package:amuwak_customer/src/data/customer_database.dart';
import 'package:amuwak_customer/src/pricing/pricing_providers.dart';
import 'package:amuwak_customer/src/sync/sync_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// A 1×1 transparent PNG — real bytes, so the preview's `Image.memory` decodes.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==');

/// Disposes the tree *inside* the test: closing the cart's real Drift stream
/// schedules a zero-duration timer, and the framework's `!timersPending` check
/// runs before a teardown pump could flush it.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

void main() {
  late CustomerDatabase db;
  late List<ImageSource> picked;

  setUp(() async {
    db = CustomerDatabase.forTesting(NativeDatabase.memory());
    picked = [];
    await db.upsertCartItem(CartItemsCompanion.insert(
      id: 'line-1',
      kind: 'weight',
      name: 'Wash & Iron',
      estKg: const Value(6),
    ));
  });
  tearDown(() async {
    await pumpEventQueue();
    await db.close();
  });

  Widget harness({bool pickerReturnsNothing = false}) => ProviderScope(
        overrides: [
          customerDatabaseProvider.overrideWithValue(db),
          pricingSettingsProvider.overrideWith((ref) => PricingSettings(
                id: 's',
                defaultRatePerKgUgx: 3000,
                updatedAt: DateTime(2026, 1, 1),
              )),
          currentCustomerProvider.overrideWith((ref) => Stream.value(
              const Customer(id: 'cust-1', name: 'Ada', phone: '0700'))),
          cartPhotoPickerProvider.overrideWithValue((source) async {
            picked.add(source);
            return pickerReturnsNothing ? null : _png;
          }),
        ],
        child: MaterialApp(theme: buildAmuwakTheme(), home: const CartScreen()),
      );

  testWidgets('a cart line offers a damage photo, then previews it',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Add damage photo'), findsOneWidget);

    await tester.tap(find.text('Add damage photo'));
    await tester.pumpAndSettle();
    // The source sheet, then capture.
    expect(find.text('Take a photo'), findsOneWidget);
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(picked, [ImageSource.camera]);
    expect(find.text('Damage photo attached'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Add damage photo'), findsNothing);

    // The key is on the line (so it reaches the order snapshot) and the bytes
    // are queued for upload.
    final item = (await db.cartItemsOnce()).single;
    expect(item.photoKey, startsWith('customer/cust-1/cart/'));
    expect((await db.localPhoto(item.photoKey!))!.bytes, _png);

    await _disposeTree(tester);
  });

  testWidgets('removing the photo returns the line to its empty state',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add damage photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(picked, [ImageSource.gallery]);

    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();

    expect(find.text('Add damage photo'), findsOneWidget);
    expect((await db.cartItemsOnce()).single.photoKey, isNull);
    expect(await db.select(db.localPhotos).get(), isEmpty);

    await _disposeTree(tester);
  });

  testWidgets('dismissing the picker leaves the line untouched',
      (tester) async {
    await tester.pumpWidget(harness(pickerReturnsNothing: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add damage photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(find.text('Add damage photo'), findsOneWidget);
    expect((await db.cartItemsOnce()).single.photoKey, isNull);

    await _disposeTree(tester);
  });
}
