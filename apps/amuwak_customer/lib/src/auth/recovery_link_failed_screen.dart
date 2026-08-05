import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';

/// Shown when a recovery link produced no session.
///
/// Supabase's PKCE flow keeps the code verifier in the localStorage of the
/// browser that requested the reset, so the emailed link only works there.
/// Opened on another device — or in an email client's isolated in-app browser
/// — the exchange fails and the user would otherwise land on /login with no
/// hint that the link was the problem, and would keep asking for more.
///
/// The wording says what to do rather than what went wrong: nothing here is
/// the user's mistake, and "the link expired" would be a lie that sends them
/// round the same loop.
class RecoveryLinkFailedScreen extends StatelessWidget {
  const RecoveryLinkFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  Text('That link could not be opened here',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'A reset link only works in the same browser you asked for '
                    'it from, on the same device. Ask for a new one here and '
                    'open it from this browser.',
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
