import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late _MockAuthService auth;

  setUp(() => auth = _MockAuthService());

  Uri url(String query) =>
      Uri.parse('https://amuwak-customer.pages.dev/$query');

  test('redeems a recovery link that carries a token hash', () async {
    when(() => auth.verifyRecoveryToken(any())).thenAnswer((_) async {});

    final result = await completeRecoveryLink(
      uri: url('?token_hash=abc123&type=recovery'),
      auth: auth,
    );

    expect(result, RecoveryLinkResult.verified);
    verify(() => auth.verifyRecoveryToken('abc123')).called(1);
  });

  test('ignores an ordinary visit', () async {
    final result = await completeRecoveryLink(uri: url(''), auth: auth);

    expect(result, RecoveryLinkResult.none);
    verifyNever(() => auth.verifyRecoveryToken(any()));
  });

  test('leaves a PKCE link alone', () async {
    // supabase_flutter redeems `?code=` itself. Touching it here would race
    // its deeplink observer for a code that can only be spent once.
    final result =
        await completeRecoveryLink(uri: url('?code=abc123'), auth: auth);

    expect(result, RecoveryLinkResult.none);
    verifyNever(() => auth.verifyRecoveryToken(any()));
  });

  test('ignores a token hash that is not a recovery', () async {
    // Signup confirmation and email-change links carry a token hash too, and
    // supabase_flutter handles those; redeeming them as a recovery would put
    // the user on a set-a-new-password screen they never asked for.
    final result = await completeRecoveryLink(
      uri: url('?token_hash=abc123&type=signup'),
      auth: auth,
    );

    expect(result, RecoveryLinkResult.none);
    verifyNever(() => auth.verifyRecoveryToken(any()));
  });

  test('reports a token that the server rejects', () async {
    // Expired, or already spent. The caller needs to tell the user, because
    // no session is established and the app otherwise looks like an ordinary
    // signed-out visit.
    when(() => auth.verifyRecoveryToken(any()))
        .thenThrow(AuthFailure('Token has expired or is invalid'));

    final result = await completeRecoveryLink(
      uri: url('?token_hash=stale&type=recovery'),
      auth: auth,
    );

    expect(result, RecoveryLinkResult.failed);
  });

  group('recoveryLinkFailed', () {
    test('a rejected token hash is a failure', () {
      // Bootstrap's verdict is the only record: a rejected hash establishes no
      // session and never reaches the auth stream at all.
      expect(
        recoveryLinkFailed(
          outcome: RecoveryLinkResult.failed,
          launchUri: url(''),
          authStreamHasError: false,
        ),
        isTrue,
      );
    });

    test('a PKCE link that errored the auth stream is a failure', () {
      // supabase_flutter redeems `?code=` itself and reports the failure as a
      // stream error rather than a return value.
      expect(
        recoveryLinkFailed(
          outcome: RecoveryLinkResult.none,
          launchUri: url('?code=abc123'),
          authStreamHasError: true,
        ),
        isTrue,
      );
    });

    test('a stream error without a recovery link is not', () {
      // A failed sign-in errors the same stream. The `code` parameter is what
      // says an emailed link is the thing that went wrong.
      expect(
        recoveryLinkFailed(
          outcome: RecoveryLinkResult.none,
          launchUri: url(''),
          authStreamHasError: true,
        ),
        isFalse,
      );
    });

    test('a PKCE link that redeemed cleanly is not', () {
      expect(
        recoveryLinkFailed(
          outcome: RecoveryLinkResult.none,
          launchUri: url('?code=abc123'),
          authStreamHasError: false,
        ),
        isFalse,
      );
    });

    test('a redeemed token hash is not', () {
      expect(
        recoveryLinkFailed(
          outcome: RecoveryLinkResult.verified,
          launchUri: url('?token_hash=abc123&type=recovery'),
          authStreamHasError: false,
        ),
        isFalse,
      );
    });
  });
}
