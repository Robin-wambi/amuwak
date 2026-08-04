import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the sticky recovery flag lives so it outlives a page reload.
///
/// Both apps override this in `main.dart` with the persistent implementation;
/// the default forgets, which is only correct where a reload cannot happen.
final recoveryIntentStoreProvider =
    Provider<RecoveryIntentStore>((ref) => InMemoryRecoveryIntentStore());

/// Remembers, across a page reload, that the user is part-way through a
/// password reset.
///
/// A reload is not a hypothetical: the recovery link lands the user on a
/// screen they may sit on for a while, and the Supabase session behind it
/// persists to localStorage. What does NOT survive is the `passwordRecovery`
/// event — supabase_flutter raises `initialSession` when it restores a stored
/// session, so anything derived from the last-seen auth event reseeds to
/// "not recovering" and both apps' gates hand the user straight on with their
/// old password still live.
///
/// Read synchronously, because the customer router's redirect and the staff
/// [AuthGate]'s `initState` both are.
abstract class RecoveryIntentStore {
  bool get isPending;
  void markPending();
  void clear();
}

/// The default. Correct everywhere the app is not really running — tests, and
/// any host without a backing store — where a "reload" cannot happen anyway.
///
/// Production overrides [recoveryIntentStoreProvider] with a
/// [PersistentRecoveryIntentStore]; see `main.dart`.
class InMemoryRecoveryIntentStore implements RecoveryIntentStore {
  bool _pending = false;

  @override
  bool get isPending => _pending;

  @override
  void markPending() => _pending = true;

  @override
  void clear() => _pending = false;
}

/// Backed by [SharedPreferences], which is localStorage on the web.
///
/// The instance is primed during bootstrap so reads can stay synchronous;
/// writes are fire-and-forget, since nothing waits on them and a lost write
/// only costs the user the same reload gap that existed before.
///
/// localStorage rather than sessionStorage on purpose: closing the tab does
/// not finish a reset. The Supabase session outlives the tab, so a pending
/// reset has to as well, and `signedOut` is what clears it.
class PersistentRecoveryIntentStore implements RecoveryIntentStore {
  PersistentRecoveryIntentStore(this._prefs);

  static const _key = 'amuwak.recovery_pending';

  final SharedPreferences _prefs;

  @override
  bool get isPending => _prefs.getBool(_key) ?? false;

  @override
  void markPending() => _prefs.setBool(_key, true);

  @override
  void clear() => _prefs.remove(_key);
}
