import 'package:amuwak_customer/src/app/customer_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CustomerApp boots to the placeholder home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));
    await tester.pumpAndSettle();

    expect(find.text('Amuwak'), findsOneWidget);
  });
}
