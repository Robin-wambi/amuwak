import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import 'recovery_state.dart';

/// Shown when a recovery link produced no session.
///
/// Two link shapes fail for two unrelated reasons, and the difference is the
/// whole value of this screen — a user told to try another browser when the
/// real problem is a spent token will hunt for a device fault that is not
/// there, and vice versa.
///
/// A rejected `token_hash` means expired or already used; it carries its own
/// proof, so where it was opened is irrelevant. A failed `?code=` means the
/// PKCE code verifier is missing, which happens exactly when the link is
/// opened outside the browser that requested it.
///
/// The wording says what to do rather than what went wrong. Neither case is
/// the user's mistake, and "the link expired" as a blanket answer would be a
/// guess that sends half of them round the same loop.
class RecoveryLinkFailedScreen extends ConsumerWidget {
  const RecoveryLinkFailedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final linkWasSpent =
        ref.watch(recoveryLinkOutcomeProvider) == RecoveryLinkResult.failed;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.link_off_outlined,
                      size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                      linkWasSpent
                          ? 'That link has already been used'
                          : 'That link could not be opened here',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    linkWasSpent
                        ? 'Reset links expire, and each one can only be used '
                            'once. Ask for a new one and open it as soon as it '
                            'arrives.'
                        : 'A reset link only works in the same browser you '
                            'asked for it from, on the same device. Ask for a '
                            'new one here and open it from this browser.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => context.go(kForgotPasswordRoute),
                    child: const Text('Request a new link'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
