import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the sticky recovery flag lives so it outlives a page reload.
///
/// Both apps override this in `main.dart` with the persistent implementation;
/// the default forgets, which is only correct where a reload cannot happen.
final recoveryIntentStoreProvider =
    Provider<RecoveryIntentStore>((ref) => InMemoryRecoveryIntentStore());

/// Remembers, across a page reload, that a particular user is part-way through
/// a password reset.
///
/// A reload is not a hypothetical: the recovery link lands the user on a
/// screen they may sit on for a while, and the Supabase session behind it
/// persists to localStorage. What does NOT survive is the `passwordRecovery`
/// event — supabase_flutter raises `initialSession` when it restores a stored
/// session, so anything derived from the last-seen auth event reseeds to
/// "not recovering" and both apps' gates hand the user straight on with their
/// old password still live.
///
/// Scoped to a user, not a device. Nothing clears the flag on `signedIn`, and
/// a session can die without ever reaching a gate as `signedOut` — so an
/// abandoned reset can outlive the session that set it. Riders share devices,
/// and an unscoped flag would hand the next person to sign in someone else's
/// reset. Releasing the latch on a sign-in-family event would be the smaller
/// change but not a safe one: `invite-staff` picks `resetPasswordForEmail`
/// over `inviteUserByEmail` precisely because invite links emit `signedIn`
/// while recovery links emit `passwordRecovery`, so clearing on `signedIn`
/// risks reopening the bug this store exists to close. Comparing user ids
/// sidesteps event ordering entirely.
///
/// Read synchronously, because the customer router's redirect and the staff
/// [AuthGate]'s `initState` both are.
abstract class RecoveryIntentStore {
  /// Whether [userId] specifically owes a password reset.
  bool isPendingFor(String userId);
  void markPending(String userId);
  void clear();
}

/// The default. Correct everywhere the app is not really running — tests, and
/// any host without a backing store — where a "reload" cannot happen anyway.
///
/// Production overrides [recoveryIntentStoreProvider] with a
/// [PersistentRecoveryIntentStore]; see `main.dart`.
class InMemoryRecoveryIntentStore implements RecoveryIntentStore {
  String? _pendingUserId;

  @override
  bool isPendingFor(String userId) => _pendingUserId == userId;

  @override
  void markPending(String userId) => _pendingUserId = userId;

  @override
  void clear() => _pendingUserId = null;
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

  static const _key = 'amuwak.recovery_pending_user';

  /// The unscoped bool a pre-scoping build wrote. A separate key rather than a
  /// changed value type at the same one, because `getString` on a key holding
  /// a bool throws rather than returning null.
  static const _legacyKey = 'amuwak.recovery_pending';

  final SharedPreferences _prefs;

  @override
  bool isPendingFor(String userId) {
    final pending = _prefs.getString(_key);
    if (pending != null) return pending == userId;
    // #104 shipped the unscoped bool and the customer PWA is live, so a
    // browser can be holding one mid-reset when this version lands. There is
    // no user id to compare against, so honour it for whoever is signed in —
    // which is what that build did. Dropping it would silently hand that user
    // the app with their old password still live.
    return _prefs.getBool(_legacyKey) ?? false;
  }

  @override
  void markPending(String userId) {
    _prefs.setString(_key, userId);
    // Otherwise both keys live at once and the legacy one keeps answering for
    // every user, which is exactly the scoping this replaces.
    _prefs.remove(_legacyKey);
  }

  @override
  void clear() {
    _prefs.remove(_key);
    _prefs.remove(_legacyKey);
  }
}
