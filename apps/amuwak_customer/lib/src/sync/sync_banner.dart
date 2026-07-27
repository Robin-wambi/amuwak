import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cart/cart_photo.dart';
import '../cart/checkout_service.dart';
import 'sync_providers.dart';

/// A slim status strip: shows an offline notice (your changes are saved and will
/// sync) or, when back online with a non-empty outbox, a "syncing N" note.
/// Hidden when online and fully synced. Reuses the brand offline/pending colors.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the outbox draining while any screen showing the banner is mounted,
    // and register the write handlers so an order or damage photo queued in a
    // previous session syncs on launch.
    ref.watch(outboxDriverProvider);
    ref.watch(placeOrderHandlerProvider);
    ref.watch(photoUploadHandlerProvider);

    final online = ref.watch(onlineProvider).valueOrNull ?? true;
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    final String? message;
    final Color bg;
    final Color fg;
    final IconData icon;
    if (!online) {
      message = "You're offline — changes are saved and will sync.";
      bg = AppColors.offlineBg;
      fg = AppColors.offlineFg;
      icon = Icons.cloud_off_outlined;
    } else if (pending > 0) {
      message = pending == 1 ? 'Syncing 1 change…' : 'Syncing $pending changes…';
      bg = AppColors.pendingBg;
      fg = AppColors.pendingFg;
      icon = Icons.sync;
    } else {
      message = null;
      bg = Colors.transparent;
      fg = Colors.transparent;
      icon = Icons.check;
    }

    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: bg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
