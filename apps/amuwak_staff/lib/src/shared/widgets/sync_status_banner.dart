import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/sync_errors_provider.dart';
import '../../sync/sync_status.dart';

/// A thin banner shown above the staff dashboard. Priority order:
///   1. Sync errors (red, tappable → opens the sync-errors screen)
///   2. Offline (orange)
///   3. Pending uploads (blue)
/// Hides itself when online, nothing pending, and no errors.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key, this.onShowErrors});

  /// Invoked when the rider taps the error state. The dashboard wires this to
  /// push the SyncErrorsScreen; left null in contexts that can't navigate.
  final VoidCallback? onShowErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider);
    final errorCount = ref.watch(syncErrorCountProvider);

    if (errorCount > 0) {
      // Compose context segments so the error state does NOT swallow the
      // offline / pending information a rider still needs (Bug 2). When the
      // device is online with nothing pending this collapses to just
      // "N sync error(s) — tap to review".
      final segments = <String>[
        if (!s.online) 'Offline',
        if (s.pendingCount > 0) '${s.pendingCount} pending',
        '$errorCount sync error${errorCount == 1 ? "" : "s"}',
      ];
      final tappable = onShowErrors != null;
      // Only promise "tap to review" when there's somewhere to navigate;
      // otherwise the copy would tell the rider to tap an inert banner.
      final label = tappable
          ? '${segments.join(" · ")} — tap to review'
          : segments.join(' · ');
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 13)),
            ),
            // Only advertise tappability (the chevron) when there's actually
            // somewhere to navigate; otherwise the banner would look
            // interactive but do nothing.
            if (tappable)
              Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onErrorContainer),
          ],
        ),
      );
      return Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: tappable
            ? InkWell(onTap: onShowErrors, child: content)
            : content,
      );
    }

    if (s.online && s.pendingCount == 0) {
      return const SizedBox.shrink();
    }
    final bg = !s.online ? AppColors.offlineBg : AppColors.pendingBg;
    final fg = !s.online ? AppColors.offlineFg : AppColors.pendingFg;
    final label = !s.online
        ? 'Offline${s.pendingCount > 0 ? " — ${s.pendingCount} pending" : ""}'
        : '${s.pendingCount} pending upload${s.pendingCount == 1 ? "" : "s"}';
    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(!s.online ? Icons.cloud_off : Icons.sync, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: fg, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
