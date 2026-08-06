import 'package:amuwak_core/amuwak_core.dart';

/// What to tell the user when submitting a 6-digit code fails.
///
/// A retryable failure never reached a verdict, so the code may well have been
/// correct. Calling it a mismatch sends the user back to re-read an
/// authenticator that was right all along — and on a rider's network the
/// dropped connection is the more common of the two cases, not the rarer one.
///
/// Shared by enrolment and the challenge: the same submitCode call backs both,
/// so they should not disagree about what went wrong.
String codeSubmitMessage(Object error) => error is AuthFailure && error.retryable
    ? 'Could not reach the server. Check your connection and try again.'
    : 'That code did not match. Try the current one.';
