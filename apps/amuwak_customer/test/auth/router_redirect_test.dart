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
      expect(
        customerAuthRedirect(
            signedIn: true, role: 'customer', location: '/login'),
        '/',
      );
      expect(
        customerAuthRedirect(
            signedIn: true, role: 'customer', location: '/signup'),
        '/',
      );
    });

    test('leaves a signed-in customer on an app route', () {
      expect(
        customerAuthRedirect(signedIn: true, role: 'customer', location: '/'),
        isNull,
      );
      expect(
        customerAuthRedirect(
            signedIn: true, role: 'customer', location: '/orders/x'),
        isNull,
      );
      expect(
        customerAuthRedirect(
            signedIn: true, role: 'customer', location: '/inbox'),
        isNull,
      );
    });

    group('a staff account signing in here', () {
      // Both apps share one auth.users, so staff credentials authenticate — but
      // this app has nothing for them. Tell them instead of rendering empty.
      for (final role in ['driver', 'in_shop', 'manager']) {
        test('$role is sent to the staff-account notice', () {
          expect(
            customerAuthRedirect(signedIn: true, role: role, location: '/'),
            kStaffAccountRoute,
          );
          expect(
            customerAuthRedirect(
                signedIn: true, role: role, location: '/orders'),
            kStaffAccountRoute,
          );
        });
      }

      test('and is left there rather than looping', () {
        expect(
          customerAuthRedirect(
              signedIn: true, role: 'driver', location: kStaffAccountRoute),
          isNull,
        );
      });

      test('is not offered the customer setup flow', () {
        expect(
          customerAuthRedirect(
              signedIn: true,
              role: 'manager',
              location: kCompleteProfileRoute),
          kStaffAccountRoute,
        );
      });
    });

    group('an account stranded mid-signup (role none)', () {
      test('is sent to finish linking, from anywhere', () {
        expect(
          customerAuthRedirect(signedIn: true, role: 'none', location: '/'),
          kCompleteProfileRoute,
        );
        expect(
          customerAuthRedirect(
              signedIn: true, role: 'none', location: '/orders/x'),
          kCompleteProfileRoute,
        );
        expect(
          customerAuthRedirect(
              signedIn: true, role: 'none', location: '/login'),
          kCompleteProfileRoute,
        );
      });

      test('and is left there rather than looping', () {
        expect(
          customerAuthRedirect(
              signedIn: true, role: 'none', location: kCompleteProfileRoute),
          isNull,
        );
      });

      test('is not left on the staff notice either', () {
        // The mirror of the staff case above: neither interstitial traps the
        // other state, so there is no way to land on a screen that cannot act
        // on your account.
        expect(
          customerAuthRedirect(
              signedIn: true, role: 'none', location: kStaffAccountRoute),
          kCompleteProfileRoute,
        );
      });

      test('reaches the app once linking mints the customer claim', () {
        expect(
          customerAuthRedirect(
              signedIn: true,
              role: 'customer',
              location: kCompleteProfileRoute),
          '/',
        );
      });
    });

    group('a null role (token missing or mid-refresh, not a verdict)', () {
      // The hook always mints one of staff/customer/none, so null means the
      // token is absent or expired — not that the account is unlinked. Bouncing
      // on it would eject a real customer during a routine token refresh.
      test('is treated as a customer, not stranded', () {
        expect(customerAuthRedirect(signedIn: true, location: '/'), isNull);
        expect(
            customerAuthRedirect(signedIn: true, location: '/orders'), isNull);
      });

      test('is still bounced off the auth pages', () {
        expect(customerAuthRedirect(signedIn: true, location: '/login'), '/');
      });
    });
  });
}
