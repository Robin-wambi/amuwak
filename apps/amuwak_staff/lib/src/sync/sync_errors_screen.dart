import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import 'repository_providers.dart';
import 'sync_errors_provider.dart';
import 'sync_failure_policy.dart';

class SyncErrorsScreen extends ConsumerWidget {
  const SyncErrorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outboxAsync = ref.watch(outboxDeadLetteredProvider);
    final pullAsync = ref.watch(pullDeadLetteredProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text(
          'Sync errors',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            // Both providers are watched in parallel above; combine them into a
            // single decision so the screen shows one loading spinner / one
            // error state instead of waterfalling the outbox spinner then the
            // pull spinner.
            if (outboxAsync.isLoading || pullAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (outboxAsync.hasError || pullAsync.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child:
                      Text('Could not load sync errors — please try again.'),
                ),
              );
            }
            final outboxRows = outboxAsync.requireValue;
            final pullRows = pullAsync.requireValue;
              if (outboxRows.isEmpty && pullRows.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No sync errors.',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (outboxRows.isNotEmpty) ...[
                    const _SectionHeader('Pending uploads (retryable)'),
                    for (final row in outboxRows)
                      _OutboxErrorTile(
                        row: row,
                        onRetry: () async {
                          try {
                            await ref
                                .read(outboxRepositoryProvider)
                                .requeue(row.id);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not retry — please '
                                    'try again.'),
                              ),
                            );
                          }
                        },
                        onDiscard: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Discard upload?'),
                              content: const Text(
                                'This change could not be saved and will be '
                                'permanently discarded from this device.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(true),
                                  child: const Text('Discard upload'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          try {
                            await ref
                                .read(outboxRepositoryProvider)
                                .discard(row.id);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not discard — please '
                                    'try again.'),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                  if (pullRows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionHeader('Server-side data (read-only)'),
                    for (final row in pullRows)
                      _PullErrorTile(
                        row: row,
                        onDismiss: () async {
                          try {
                            await ref
                                .read(pullDeadLetterRepositoryProvider)
                                .delete(row.id);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not dismiss — please '
                                    'try again.'),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ],
              );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _OutboxErrorTile extends StatelessWidget {
  const _OutboxErrorTile({
    required this.row,
    required this.onRetry,
    required this.onDiscard,
  });
  final OutboxData row;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // Opt out of the global branded CardTheme (orange hairline + 22px radius);
      // these are dense diagnostic list rows, not brand content cards.
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(
          '${row.forTable} · ${row.op} · ${row.rowId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          friendlySyncError(row.lastError),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            TextButton(onPressed: onDiscard, child: const Text('Discard')),
          ],
        ),
      ),
    );
  }
}

class _PullErrorTile extends StatelessWidget {
  const _PullErrorTile({required this.row, required this.onDismiss});
  final PullDeadLetterData row;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // Opt out of the global branded CardTheme (orange hairline + 22px radius);
      // these are dense diagnostic list rows, not brand content cards.
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(
          '${row.forTable} · server row',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          friendlyPullError(row.errorText),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Chip(
              label: Text(
                'Server fix required',
                style: TextStyle(fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}
