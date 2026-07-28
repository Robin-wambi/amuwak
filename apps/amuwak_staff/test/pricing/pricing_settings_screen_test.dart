import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amuwak_staff/src/pricing/pricing_settings.dart';
import 'package:amuwak_staff/src/pricing/pricing_settings_screen.dart';

/// Captures the values passed to [PricingSettingsScreen.save].
class _Saved {
  double? rate;
  int? deliveryFee;
  int? expressFlat;
  double? expressPct;
  bool called = false;
}

PricingSettings _settings({
  double rate = 5000,
  int deliveryFee = 0,
  int expressFlat = 0,
  double expressPct = 0,
}) =>
    PricingSettings(
      id: 'p1',
      defaultRatePerKgUgx: rate,
      updatedAt: DateTime.utc(2026, 6, 6),
      deliveryFeeUgx: deliveryFee,
      expressFlatUgx: expressFlat,
      expressPct: expressPct,
    );

Widget _screen(_Saved saved, {PricingSettings? initial}) => MaterialApp(
      home: PricingSettingsScreen(
        load: () async => initial ?? _settings(),
        save: ({
          required ratePerKgUgx,
          required deliveryFeeUgx,
          required expressFlatUgx,
          required expressPct,
        }) async {
          saved
            ..rate = ratePerKgUgx
            ..deliveryFee = deliveryFeeUgx
            ..expressFlat = expressFlatUgx
            ..expressPct = expressPct
            ..called = true;
        },
      ),
    );

void main() {
  testWidgets('pre-fills every field and saves all values', (tester) async {
    final saved = _Saved();
    await tester.pumpWidget(_screen(saved,
        initial: _settings(
            rate: 5000, deliveryFee: 3000, expressFlat: 2000, expressPct: 30)));
    await tester.pumpAndSettle();
    expect(find.text('5000'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
    expect(find.text('2000'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('settings_rate')), '6000');
    await tester.enterText(
        find.byKey(const Key('settings_delivery_fee')), '3500');
    await tester.enterText(
        find.byKey(const Key('settings_express_flat')), '2500');
    await tester.enterText(
        find.byKey(const Key('settings_express_pct')), '25');
    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pump();

    expect(saved.rate, 6000);
    expect(saved.deliveryFee, 3500);
    expect(saved.expressFlat, 2500);
    expect(saved.expressPct, 25);
    expect(find.text('Pricing settings saved.'), findsOneWidget);
  });

  testWidgets('rounds a fractional rate before saving', (tester) async {
    final saved = _Saved();
    await tester.pumpWidget(_screen(saved));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings_rate')), '5000.7');
    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pump();
    expect(saved.rate, 5001);
  });

  testWidgets('rejects a positive rate that rounds to zero', (tester) async {
    final saved = _Saved();
    await tester.pumpWidget(_screen(saved));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings_rate')), '0.4');
    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pump();
    expect(saved.called, isFalse);
    expect(find.text('Enter a rate greater than 0.'), findsOneWidget);
  });

  testWidgets('blank delivery/express fields default to zero', (tester) async {
    final saved = _Saved();
    await tester.pumpWidget(_screen(saved));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settings_delivery_fee')), '');
    await tester.enterText(find.byKey(const Key('settings_express_flat')), '');
    await tester.enterText(find.byKey(const Key('settings_express_pct')), '');
    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pump();
    expect(saved.deliveryFee, 0);
    expect(saved.expressFlat, 0);
    expect(saved.expressPct, 0);
  });

  testWidgets('rejects a negative fee', (tester) async {
    final saved = _Saved();
    await tester.pumpWidget(_screen(saved));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('settings_delivery_fee')), '-100');
    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pump();
    expect(saved.called, isFalse);
    expect(find.text('Fees and percentage must be 0 or more.'), findsOneWidget);
  });

  testWidgets('rejects an express percentage of 1000 or more', (tester) async {
    final saved = _Saved();
    await tester.pumpWidget(_screen(saved));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('settings_express_pct')), '1000');
    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pump();
    expect(saved.called, isFalse);
    expect(find.text('Express percentage must be below 1000.'), findsOneWidget);
  });

  testWidgets('a failed load shows the error message instead of the form',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PricingSettingsScreen(
        load: () async => throw Exception('no settings'),
        save: ({
          required ratePerKgUgx,
          required deliveryFeeUgx,
          required expressFlatUgx,
          required expressPct,
        }) async {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pricing settings missing — contact admin.'),
        findsOneWidget);
    expect(find.byKey(const Key('settings_rate')), findsNothing);
  });

  testWidgets('a failed save surfaces a retry SnackBar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PricingSettingsScreen(
        load: () async => _settings(),
        save: ({
          required ratePerKgUgx,
          required deliveryFeeUgx,
          required expressFlatUgx,
          required expressPct,
        }) async =>
            throw Exception('network down'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pump();

    expect(find.text('Could not save — please retry.'), findsOneWidget);
  });

  testWidgets('the Manage service items button invokes onManageCatalog',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: PricingSettingsScreen(
        load: () async => _settings(),
        save: ({
          required ratePerKgUgx,
          required deliveryFeeUgx,
          required expressFlatUgx,
          required expressPct,
        }) async {},
        onManageCatalog: () => tapped = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_manage_catalog')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
