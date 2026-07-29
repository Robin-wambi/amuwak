import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('passwordPolicyError', () {
    test('rejects anything shorter than 8 characters', () {
      expect(passwordPolicyError('short12'), isNotNull);
      expect(passwordPolicyError(''), isNotNull);
      expect(passwordPolicyError(null), isNotNull);
    });

    test('accepts 8 characters', () {
      expect(passwordPolicyError('12345678'), isNull);
    });

    test('accepts a long passphrase', () {
      // NIST SP 800-63B Rev 4 says verifiers SHALL support at least 64
      // characters. A passphrase is the outcome the policy is steering toward.
      expect(
        passwordPolicyError('correct horse battery staple and then some more'),
        isNull,
      );
    });

    test('does not impose character-composition rules', () {
      // Rev 4 uses SHALL NOT here: requiring an uppercase letter, a digit or a
      // symbol is prohibited, not merely discouraged. Length plus breach
      // screening (Supabase/HIBP) replaces it.
      expect(passwordPolicyError('alllowercaseletters'), isNull);
      expect(passwordPolicyError('11111111'), isNull);
    });

    test('does not reject leading or trailing spaces', () {
      // Trimming a password silently changes what the user typed, and space is
      // a legal character in a passphrase.
      expect(passwordPolicyError('  spaced out  '), isNull);
    });
  });
}
