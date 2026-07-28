import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/auth/complete_profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfiles extends Mock implements CustomerProfileRepository {}

void main() {
  late _MockAuthService auth;
  late _MockProfiles profiles;
  late CompleteProfileController controller;

  setUp(() {
    auth = _MockAuthService();
    profiles = _MockProfiles();
    controller = CompleteProfileController(
        authService: auth, profileRepository: profiles);
  });

  void stubHappyPath() {
    when(() => profiles.linkOrCreate(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        )).thenAnswer((_) async => 'cust-77');
    when(() => auth.refreshSession()).thenAnswer((_) async {});
  }

  test('links the customer, then refreshes — in that order', () async {
    stubHappyPath();

    final id = await controller.complete(
      name: 'Ada',
      phone: '+256700123456',
      email: 'ada@example.com',
    );

    expect(id, 'cust-77');
    // The refresh must come last: the `customer` role claim is only minted once
    // the link exists, and the router keys off that claim.
    verifyInOrder([
      () => profiles.linkOrCreate(
          name: 'Ada', phone: '+256700123456', email: 'ada@example.com'),
      () => auth.refreshSession(),
    ]);
  });

  test('does not create the auth user — it already exists', () async {
    stubHappyPath();

    await controller.complete(
        name: 'Ada', phone: '0700123456', email: 'ada@example.com');

    verifyNever(() => auth.signUpWithEmailPassword(
        email: any(named: 'email'), password: any(named: 'password')));
  });

  test('a failed link does not refresh the session', () async {
    when(() => profiles.linkOrCreate(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        )).thenThrow(Exception('offline'));

    await expectLater(
      controller.complete(
          name: 'Ada', phone: '0700123456', email: 'ada@example.com'),
      throwsException,
    );
    // Refreshing after a failed link would mint a token that still says 'none',
    // leaving the user bounced back to this screen with no explanation.
    verifyNever(() => auth.refreshSession());
  });

  test('re-running against an already-linked account is safe', () async {
    // link_or_create_customer is idempotent: it returns the existing link
    // rather than raising, so a retry (or a double tap) is harmless.
    stubHappyPath();

    final first = await controller.complete(
        name: 'Ada', phone: '0700123456', email: 'ada@example.com');
    final second = await controller.complete(
        name: 'Ada', phone: '0700123456', email: 'ada@example.com');

    expect(first, second);
  });
}
