import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The key a pre-scoping build wrote. Duplicated here rather than exported,
/// because nothing but this test should still care about it.
const _legacyKey = 'amuwak.recovery_pending';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryRecoveryIntentStore', () {
    test('owes nothing until something is marked', () {
      expect(InMemoryRecoveryIntentStore().isPendingFor('u1'), isFalse);
    });

    test('remembers the user the reset belongs to', () {
      final store = InMemoryRecoveryIntentStore()..markPending('u1');
      expect(store.isPendingFor('u1'), isTrue);
    });

    test('does not hand one user the reset another user abandoned', () {
      // The reason for scoping at all: riders share devices, and an abandoned
      // invite must not push the next person onto Set Password.
      final store = InMemoryRecoveryIntentStore()..markPending('u1');
      expect(store.isPendingFor('u2'), isFalse);
    });

    test('clear ends the reset', () {
      final store = InMemoryRecoveryIntentStore()..markPending('u1');
      store.clear();
      expect(store.isPendingFor('u1'), isFalse);
    });
  });

  group('PersistentRecoveryIntentStore', () {
    test('survives being rebuilt from the same backing store', () async {
      // Standing in for a relaunch: same localStorage, brand new object.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      PersistentRecoveryIntentStore(prefs).markPending('u1');

      expect(PersistentRecoveryIntentStore(prefs).isPendingFor('u1'), isTrue);
    });

    test('scopes the persisted reset to its own user', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PersistentRecoveryIntentStore(prefs)..markPending('u1');

      expect(store.isPendingFor('u2'), isFalse);
    });

    test('clear removes the reset', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PersistentRecoveryIntentStore(prefs)..markPending('u1');

      store.clear();

      expect(store.isPendingFor('u1'), isFalse);
    });

    test('honours a reset left behind by a pre-scoping build', () async {
      // #104 shipped an unscoped bool at this key and the customer PWA is
      // live, so a browser can be holding one mid-reset when this version
      // lands. There is no user id to compare against, so the only safe
      // reading is the one that build meant: whoever is here owes a reset.
      // Dropping it would silently reopen the bug #107 exists to close.
      SharedPreferences.setMockInitialValues({_legacyKey: true});
      final prefs = await SharedPreferences.getInstance();

      expect(PersistentRecoveryIntentStore(prefs).isPendingFor('u1'), isTrue);
    });

    test('clear also retires the pre-scoping key', () async {
      // Otherwise the legacy true outlives the reset it described and every
      // later launch demands a new password.
      SharedPreferences.setMockInitialValues({_legacyKey: true});
      final prefs = await SharedPreferences.getInstance();
      final store = PersistentRecoveryIntentStore(prefs);

      store.clear();

      expect(store.isPendingFor('u1'), isFalse);
      expect(prefs.containsKey(_legacyKey), isFalse);
    });

    test('marking a scoped reset retires the pre-scoping key', () async {
      // Both keys live at once otherwise, and the legacy one answers for every
      // user — which is exactly the scoping this change adds.
      SharedPreferences.setMockInitialValues({_legacyKey: true});
      final prefs = await SharedPreferences.getInstance();
      final store = PersistentRecoveryIntentStore(prefs)..markPending('u1');

      expect(store.isPendingFor('u2'), isFalse);
      expect(prefs.containsKey(_legacyKey), isFalse);
    });
  });
}
