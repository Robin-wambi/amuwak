import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockMfa extends Mock implements GoTrueMFAApi {}

class _FakeVerifyResponse extends Fake implements AuthMFAVerifyResponse {}

class _FakeUnenrollResponse extends Fake implements AuthMFAUnenrollResponse {}

Factor _factor(String id, FactorStatus status) => Factor(
      id: id,
      status: status,
      factorType: FactorType.totp,
      friendlyName: 'Authenticator',
      updatedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockGoTrue goTrue;
  late _MockMfa mfa;
  late MfaService service;

  // factorType is a non-nullable enum, so any(named:) needs a fallback.
  setUpAll(() => registerFallbackValue(FactorType.totp));

  setUp(() {
    goTrue = _MockGoTrue();
    mfa = _MockMfa();
    when(() => goTrue.mfa).thenReturn(mfa);
    service = MfaService(goTrue: goTrue);
  });

  group('enrollTotp', () {
    test('returns the QR, the secret and the factor id', () async {
      when(() => mfa.enroll(
              factorType: any(named: 'factorType'),
              issuer: any(named: 'issuer'),
              friendlyName: any(named: 'friendlyName')))
          .thenAnswer((_) async => const AuthMFAEnrollResponse(
                id: 'factor-1',
                type: FactorType.totp,
                totp: TOTPEnrollment(
                    qrCode: '<svg/>', secret: 'SECRET', uri: 'otpauth://x'),
              ));

      final enrolment = await service.enrollTotp();

      // The secret is offered alongside the QR because a rider on a cracked
      // screen may not be able to scan one.
      expect(enrolment.factorId, 'factor-1');
      expect(enrolment.secret, 'SECRET');
      expect(enrolment.qrCodeSvg, '<svg/>');
      // The raw otpauth URI too: the apps already ship qr_flutter for order
      // tags, so they render this themselves rather than pulling in an SVG
      // renderer just for Supabase's pre-drawn QR.
      expect(enrolment.otpauthUri, 'otpauth://x');
    });

    test('wraps AuthException in AuthFailure', () async {
      when(() => mfa.enroll(
              factorType: any(named: 'factorType'),
              issuer: any(named: 'issuer'),
              friendlyName: any(named: 'friendlyName')))
          .thenThrow(const AuthException('already enrolled'));

      await expectLater(service.enrollTotp(), throwsA(isA<AuthFailure>()));
    });
  });

  group('submitCode', () {
    test('challenges and verifies in one step', () async {
      when(() => mfa.challengeAndVerify(
              factorId: any(named: 'factorId'), code: any(named: 'code')))
          .thenAnswer((_) async => _FakeVerifyResponse());

      await service.submitCode(factorId: 'factor-1', code: '123456');

      verify(() => mfa.challengeAndVerify(factorId: 'factor-1', code: '123456'))
          .called(1);
    });

    test('wraps a wrong code in AuthFailure', () async {
      when(() => mfa.challengeAndVerify(
              factorId: any(named: 'factorId'), code: any(named: 'code')))
          .thenThrow(const AuthException('Invalid TOTP code entered'));

      await expectLater(
        service.submitCode(factorId: 'factor-1', code: '000000'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('needsChallenge', () {
    test('is true when a verified factor exists but this session is aal1', () {
      when(() => mfa.getAuthenticatorAssuranceLevel()).thenReturn(
        AuthMFAGetAuthenticatorAssuranceLevelResponse(
          currentLevel: AuthenticatorAssuranceLevels.aal1,
          nextLevel: AuthenticatorAssuranceLevels.aal2,
          currentAuthenticationMethods: const [],
        ),
      );

      expect(service.needsChallenge, isTrue);
    });

    test('is false once the session has cleared the second factor', () {
      when(() => mfa.getAuthenticatorAssuranceLevel()).thenReturn(
        AuthMFAGetAuthenticatorAssuranceLevelResponse(
          currentLevel: AuthenticatorAssuranceLevels.aal2,
          nextLevel: AuthenticatorAssuranceLevels.aal2,
          currentAuthenticationMethods: const [],
        ),
      );

      expect(service.needsChallenge, isFalse);
    });

    test('is false for a user who has not enrolled at all', () {
      when(() => mfa.getAuthenticatorAssuranceLevel()).thenReturn(
        AuthMFAGetAuthenticatorAssuranceLevelResponse(
          currentLevel: AuthenticatorAssuranceLevels.aal1,
          nextLevel: AuthenticatorAssuranceLevels.aal1,
          currentAuthenticationMethods: const [],
        ),
      );

      expect(service.needsChallenge, isFalse);
    });

    test('is false when there is no session to reason about', () {
      when(() => mfa.getAuthenticatorAssuranceLevel()).thenReturn(
        AuthMFAGetAuthenticatorAssuranceLevelResponse(
          currentLevel: null,
          nextLevel: null,
          currentAuthenticationMethods: const [],
        ),
      );

      expect(service.needsChallenge, isFalse);
    });
  });

  group('verifiedFactors', () {
    test('ignores factors left unverified by an abandoned enrolment', () async {
      // Starting enrolment and closing the app leaves an unverified factor
      // behind. Counting it as MFA would lock the user out of their account.
      when(() => mfa.listFactors()).thenAnswer((_) async =>
          AuthMFAListFactorsResponse(
            all: [
              _factor('done', FactorStatus.verified),
              _factor('abandoned', FactorStatus.unverified),
            ],
            totp: [
              _factor('done', FactorStatus.verified),
              _factor('abandoned', FactorStatus.unverified),
            ],
            phone: const [],
          ));

      final factors = await service.verifiedFactors();

      expect(factors.map((f) => f.id), ['done']);
    });
  });

  group('removeFactor', () {
    test('unenrolls the given factor', () async {
      when(() => mfa.unenroll(any()))
          .thenAnswer((_) async => _FakeUnenrollResponse());

      await service.removeFactor('factor-1');

      verify(() => mfa.unenroll('factor-1')).called(1);
    });
  });
}
