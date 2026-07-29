/// The one password rule both apps apply, so signup, reset and the staff
/// set-password screen cannot drift apart.
///
/// Follows NIST SP 800-63B Rev. 4 (July 2025):
///
/// - **8 characters minimum.** Rev 4 allows 8 only when a second authenticator
///   exists, and requires 15 for a password standing alone. TOTP MFA is the
///   other half of that bargain; until it ships, 8 is the pragmatic floor
///   rather than the compliant one.
/// - **No composition rules.** Rev 4 says verifiers SHALL NOT require
///   uppercase, digits or symbols. Length plus breach screening replaces them,
///   and the screening is Supabase's Leaked Password Protection (HaveIBeenPwned)
///   rather than anything client-side — a client cannot be trusted with it.
/// - **No maximum below 64**, and no trimming: a space is a legal character in
///   a passphrase, and silently altering what the user typed makes the password
///   they set differ from the one they remember.
///
/// Returns null when the password is acceptable, or the message to show.
const kMinPasswordLength = 8;

String? passwordPolicyError(String? password) =>
    (password ?? '').length < kMinPasswordLength
        ? 'Use at least $kMinPasswordLength characters'
        : null;
