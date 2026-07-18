import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:amuwak_customer/src/auth/signup_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfiles extends Mock implements CustomerProfileRepository {}

void main() {
  late _MockAuthService auth;
  late _MockProfiles profiles;
  late SignupController controller;

  setUp(() {
    auth = _MockAuthService();
    profiles = _MockProfiles();
    controller =
        SignupController(authService: auth, profileRepository: profiles);
  });

  test('signs up, links the customer, then refreshes — in that order', () async {
    when(() => auth.signUpWithEmailPassword(
        email: any(named: 'email'),
        password: any(named: 'password'))).thenAnswer((_) async {});
    when(() => profiles.linkOrCreate(
          name: any(named: 'name'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        )).thenAnswer((_) async => 'cust-99');
    when(() => auth.refreshSession()).thenAnswer((_) async {});

    final id = await controller.signUp(
      name: 'Ada',
      email: 'ada@example.com',
      phone: '+256700123456',
      password: 'secret6',
    );

    expect(id, 'cust-99');
    verifyInOrder([
      () => auth.signUpWithEmailPassword(
          email: 'ada@example.com', password: 'secret6'),
      () => profiles.linkOrCreate(
          name: 'Ada', phone: '+256700123456', email: 'ada@example.com'),
      () => auth.refreshSession(),
    ]);
  });

  test('does not link when signup fails', () async {
    when(() => auth.signUpWithEmailPassword(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(AuthFailure('User already registered'));

    await expectLater(
      controller.signUp(
          name: 'Ada', email: 'a@b.co', phone: '0700123456', password: 'x'),
      throwsA(isA<AuthFailure>()),
    );
    verifyNever(() => profiles.linkOrCreate(
        name: any(named: 'name'),
        phone: any(named: 'phone'),
        email: any(named: 'email')));
  });
}
