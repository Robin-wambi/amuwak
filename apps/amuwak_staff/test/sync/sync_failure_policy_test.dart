import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amuwak_staff/src/sync/sync_failure_policy.dart';

void main() {
  group('isTransientSyncError', () {
    test('treats socket / timeout / client transport errors as transient', () {
      expect(isTransientSyncError(SocketException('failed host lookup')),
          isTrue);
      expect(isTransientSyncError(TimeoutException('slow')), isTrue);
      expect(
          isTransientSyncError(
              Exception('ClientException: Connection closed before full header')),
          isTrue);
      expect(
          isTransientSyncError('Connection refused (os error 111)'),
          isTrue);
    });

    test('treats a Postgrest data rejection as NON-transient', () {
      expect(
          isTransientSyncError(
              const PostgrestException(message: 'duplicate key', code: '23505')),
          isFalse);
    });

    test('treats an unknown-op StateError as NON-transient', () {
      expect(isTransientSyncError(StateError('unknown op "frobnicate"')),
          isFalse);
    });

    test('detects handshake/timeout via class-name string (obfuscated builds)',
        () {
      // In --obfuscate / release-web builds runtimeType names are mangled, so
      // detection must also work off the toString() class-name substring.
      expect(
          isTransientSyncError('HandshakeException: Handshake error in client'),
          isTrue);
      expect(isTransientSyncError('TimeoutException after 0:00:30.000000'),
          isTrue);
    });

    test('does not treat a bare "connection closed" server message as transient',
        () {
      // Narrowed to "connection closed before" (what dart:http actually emits
      // for a true transport drop) so a server/proxy message mentioning a
      // closed connection is not misclassified as retryable.
      expect(isTransientSyncError('relation "x" connection closed by policy'),
          isFalse);
      expect(
          isTransientSyncError('ClientException: Connection closed before '
              'full header was received'),
          isTrue);
    });
  });

  group('friendlySyncError', () {
    test('maps null / empty to a generic line', () {
      expect(friendlySyncError(null), 'Could not be saved.');
      expect(friendlySyncError('   '), 'Could not be saved.');
    });

    test('maps known Postgres codes to plain language', () {
      expect(friendlySyncError('23505: duplicate key value'),
          'Already saved on the server.');
      expect(friendlySyncError('23503: violates foreign key constraint'),
          'Linked record is missing on the server.');
      expect(friendlySyncError('new row violates row-level security policy'),
          'Not allowed on the server (permissions).');
      expect(friendlySyncError('JWT expired'),
          'Sign-in expired — sign out and back in.');
    });

    test('maps transport text to a Retry hint (not an auto-retry promise)', () {
      // friendlySyncError is only shown on DEAD-LETTERED rows, which do NOT
      // retry on their own — so the message must point at the Retry button
      // rather than promising automatic recovery.
      expect(friendlySyncError('SocketException: failed host lookup'),
          'Connection problem — tap Retry to try again.');
    });

    test('falls back to a server-rejected line', () {
      expect(friendlySyncError('42P01: relation does not exist'),
          'Could not be saved (server rejected it).');
    });

    test('over-broad words alone do not trigger specific messages', () {
      // "duplicate" without "key" and "permission" without "denied" must NOT
      // be mistaken for the server unique-violation / RLS messages.
      expect(friendlySyncError('Duplicate scan ignored locally'),
          'Could not be saved (server rejected it).');
      expect(friendlySyncError('Camera permission is required'),
          'Could not be saved (server rejected it).');
    });

    test('status codes only match as standalone tokens, not embedded digits',
        () {
      // "401"/"403" embedded in a longer number or identifier must NOT be
      // mistaken for an auth/permission rejection.
      expect(friendlySyncError('Gave up after 4012 retries'),
          'Could not be saved (server rejected it).');
      expect(friendlySyncError('42P01: relation does not exist'),
          'Could not be saved (server rejected it).');
      // A genuine standalone status code still maps.
      expect(friendlySyncError('AuthException statusCode: 401'),
          'Sign-in expired — sign out and back in.');
      expect(friendlySyncError('request failed with status 403'),
          'Not allowed on the server (permissions).');
    });
  });

  group('friendlyPullError', () {
    test('maps server-read errors (generic/RLS/JWT/transient) to read-oriented '
        'lines', () {
      expect(friendlyPullError(null), 'Server data could not be loaded.');
      expect(friendlyPullError('   '), 'Server data could not be loaded.');
      expect(friendlyPullError('TypeError: null is not a String'),
          'Server data could not be loaded — needs a fix on the server.');
      expect(friendlyPullError('new row violates row-level security policy'),
          'Not allowed to read this from the server (permissions).');
      expect(friendlyPullError('JWT expired'),
          'Sign-in expired — sign out and back in.');
      expect(friendlyPullError('SocketException: failed host lookup'),
          'Connection problem — could not load this server data.');
    });
  });
}
