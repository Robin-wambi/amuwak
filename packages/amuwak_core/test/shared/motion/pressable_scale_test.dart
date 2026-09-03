import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_core/amuwak_core.dart';

void main() {
  testWidgets('forwards tap to onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableScale(
            onTap: () => tapped = true,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PressableScale));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('scales down while pressed and returns to 1 after release',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableScale(
            onTap: () {},
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    AnimatedScale scaleWidget() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scaleWidget().scale, 1.0);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump(); // dispatch tap-down
    expect(scaleWidget().scale, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleWidget().scale, 1.0);
  });

  testWidgets('reduced motion keeps the scale at 1 while pressed',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: Scaffold(
              body: PressableScale(
                onTap: () {},
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
    await gesture.up();
  });

  testWidgets('activates via Enter, numpad Enter, and Space when focused',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableScale(
            onTap: () => tapCount++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    Focus.of(tester.element(find.byType(SizedBox))).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tapCount, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump();
    expect(tapCount, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(tapCount, 3);
  });

  testWidgets('shows a focus outline while focused and hides it once unfocused',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableScale(
            onTap: () {},
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    Decoration? outlineDecoration() => tester
        .widget<Container>(find.descendant(
          of: find.byType(PressableScale),
          matching: find.byType(Container),
        ))
        .decoration;

    expect(outlineDecoration(), isNull);

    final focusNode = Focus.of(tester.element(find.byType(SizedBox)));
    focusNode.requestFocus();
    await tester.pump();
    final decoration = outlineDecoration();
    expect(decoration, isNotNull);
    // Matches AppCard's own corner radius, since every tappable AppCard
    // routes through here — a mismatched radius would poke past the card.
    expect(
      (decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(AppRadii.card),
    );

    focusNode.unfocus();
    await tester.pumpAndSettle();
    expect(outlineDecoration(), isNull);
  });
}
