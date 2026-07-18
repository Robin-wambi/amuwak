import 'package:amuwak_customer/src/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('customerAuthRedirect', () {
    test('sends a signed-out visitor to /login', () {
      expect(customerAuthRedirect(signedIn: false, location: '/'), '/login');
      expect(customerAuthRedirect(signedIn: false, location: '/orders/x'),
          '/login');
    });

    test('lets a signed-out visitor sit on the auth pages', () {
      expect(customerAuthRedirect(signedIn: false, location: '/login'), isNull);
      expect(
          customerAuthRedirect(signedIn: false, location: '/signup'), isNull);
    });

    test('bounces a signed-in customer off the auth pages to /', () {
      expect(customerAuthRedirect(signedIn: true, location: '/login'), '/');
      expect(customerAuthRedirect(signedIn: true, location: '/signup'), '/');
    });

    test('leaves a signed-in customer on an app route', () {
      expect(customerAuthRedirect(signedIn: true, location: '/'), isNull);
      expect(customerAuthRedirect(signedIn: true, location: '/orders/x'),
          isNull);
      expect(customerAuthRedirect(signedIn: true, location: '/inbox'), isNull);
    });
  });
}
