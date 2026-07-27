import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

import '../customer_photo_url.dart';

/// Thumbnails are far smaller than a card, so [AppRadii.card] / `field` would
/// round them almost to circles.
const _thumbRadius = 10.0;

/// The itemized cart behind a customer-app order: what the customer said they
/// were sending, and photos of any garment they flagged as damaged or stained —
/// the warning staff need BEFORE the load goes in a machine.
///
/// Read-only. Staff still weigh the pickup and set the real price; this is the
/// customer's declaration, not a bill.
class CustomerItemsSection extends StatelessWidget {
  const CustomerItemsSection({
    super.key,
    required this.items,
    this.photoUrl,
    this.title = 'What the customer sent',
  });

  final List<CartSnapshotItem> items;

  /// Resolves a signed URL per photo. Null (or a null result) renders a
  /// placeholder — the order screen must stay usable offline.
  final CustomerPhotoUrlResolver? photoUrl;

  final String title;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final flagged = items.where((i) => i.hasPhoto).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smartphone, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Text('${items.length} item${items.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          if (flagged > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _DamageWarning(count: flagged),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final item in items)
            _CustomerItemRow(item: item, photoUrl: photoUrl),
        ],
      ),
    );
  }
}

/// Amber, not red: it's a heads-up to inspect, not an error state.
class _DamageWarning extends StatelessWidget {
  const _DamageWarning({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Row(
        children: [
          Icon(Icons.report_problem_outlined,
              size: 16, color: AppColors.pendingFg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              count == 1
                  ? 'Customer flagged 1 item as damaged — check before washing.'
                  : 'Customer flagged $count items as damaged — check before washing.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.pendingFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerItemRow extends StatelessWidget {
  const _CustomerItemRow({required this.item, required this.photoUrl});

  final CartSnapshotItem item;
  final CustomerPhotoUrlResolver? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isWeight ? Icons.local_laundry_service_outlined
                          : Icons.checkroom_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.bodyMedium),
                Text(item.subtitle, style: theme.textTheme.bodySmall),
                if (item.note != null && item.note!.trim().isNotEmpty)
                  Text('Note: ${item.note}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          if (item.hasPhoto) ...[
            const SizedBox(width: AppSpacing.sm),
            DamagePhotoThumb(objectKey: item.photoKey!, photoUrl: photoUrl),
          ],
        ],
      ),
    );
  }
}

/// A customer damage photo, fetched through a signed URL (the bucket is
/// private). Tapping opens it full-screen. Anything that can go wrong — offline,
/// an upload still queued on the customer's device, an expired link — lands on
/// the same quiet placeholder instead of an error.
class DamagePhotoThumb extends StatefulWidget {
  const DamagePhotoThumb({
    super.key,
    required this.objectKey,
    required this.photoUrl,
    this.size = 48,
  });

  final String objectKey;
  final CustomerPhotoUrlResolver? photoUrl;
  final double size;

  @override
  State<DamagePhotoThumb> createState() => _DamagePhotoThumbState();
}

class _DamagePhotoThumbState extends State<DamagePhotoThumb> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(DamagePhotoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.objectKey != widget.objectKey ||
        oldWidget.photoUrl != widget.photoUrl) {
      _resolve();
    }
  }

  void _resolve() {
    final resolver = widget.photoUrl;
    _url = resolver == null ? Future.value(null) : resolver(widget.objectKey);
  }

  void _openFullScreen(String url) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url, errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text("Couldn't load this photo."),
                )),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        final url = snapshot.data;
        final child = url == null
            ? _Placeholder(
                size: widget.size,
                waiting:
                    snapshot.connectionState == ConnectionState.waiting,
              )
            : Image.network(
                url,
                height: widget.size,
                width: widget.size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Placeholder(size: widget.size),
              );

        return GestureDetector(
          onTap: url == null ? null : () => _openFullScreen(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_thumbRadius),
            child: SizedBox(
              height: widget.size,
              width: widget.size,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, this.waiting = false});

  final double size;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: waiting
            ? SizedBox(
                height: size / 3,
                width: size / 3,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Tooltip(
                message: 'Photo not available yet — it loads when online.',
                child: Icon(Icons.image_not_supported_outlined,
                    size: size / 2.5, color: theme.colorScheme.outline),
              ),
      ),
    );
  }
}
