import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/customer_session.dart';
import '../data/customer_database.dart';
import 'add_item_sheets.dart';
import 'cart_photo.dart';
import 'cart_providers.dart';
import 'checkout_sheet.dart';
import 'photo_capture.dart';

/// The cart: edit lines, watch the running estimate + free-delivery progress,
/// and check out. Reads the local Drift cart (works offline).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider).valueOrNull ?? const <CartItem>[];
    final estimate = ref.watch(cartEstimateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: items.isEmpty
          ? _EmptyCart(onBrowse: () => context.go('/'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _CartItemTile(item: item),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showAddLaundrySheet(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Add laundry'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showAddSpecialtySheet(context, ref),
                        icon: const Icon(Icons.checkroom_outlined),
                        label: const Text('Specialty'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: (items.isEmpty || estimate == null)
          ? null
          : _SummaryFooter(
              estimate: estimate,
              onCheckout: () => showCheckoutSheet(context, ref),
            ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(cartRepositoryProvider);
    final isPiece = item.kind == 'piece';
    final subtitle = isPiece
        ? '${formatUgx(item.unitUgx ?? 0)} each'
        : '~${(item.estKg ?? 0).toStringAsFixed(item.estKg == null ? 0 : (item.estKg! % 1 == 0 ? 0 : 1))} kg · weighed at pickup';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                    if (item.note != null && item.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Note: ${item.note}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
              if (isPiece) ...[
                _QtyStepper(
                  qty: item.qty,
                  onChanged: (q) => repo.setQty(item, q),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(formatUgx((item.unitUgx ?? 0) * item.qty),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => repo.remove(item.id),
              ),
            ],
          ),
          _DamagePhotoRow(item: item),
        ],
      ),
    );
  }
}

/// Attach / preview / remove a photo of a damaged or stained garment, so staff
/// are warned before they wash it. Capture is offline-safe: the compressed bytes
/// live in the local DB and the upload drains from the outbox.
class _DamagePhotoRow extends ConsumerStatefulWidget {
  const _DamagePhotoRow({required this.item});

  final CartItem item;

  @override
  ConsumerState<_DamagePhotoRow> createState() => _DamagePhotoRowState();
}

class _DamagePhotoRowState extends ConsumerState<_DamagePhotoRow> {
  bool _busy = false;

  Future<void> _attach(ImageSource source) async {
    final customerId = ref.read(currentCustomerIdProvider);
    if (customerId == null) {
      _snack('Still loading your details — try again in a moment.');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(cartPhotoPickerProvider)(source);
      // The picker is a full-screen detour — the cart may be gone by now.
      if (bytes == null || !mounted) return;
      await ref.read(cartPhotoServiceProvider).attach(
            item: widget.item,
            bytes: bytes,
            customerId: customerId,
          );
    } on PlatformException catch (e) {
      _snack(switch (e.code) {
        'camera_access_denied' =>
          'Camera permission denied. Enable it in Settings to take photos.',
        'photo_access_denied' =>
          'Photo permission denied. Enable it in Settings to attach a photo.',
        'no_available_camera' => 'No camera is available on this device.',
        _ => 'Could not open the camera. Please try again.',
      });
    } catch (_) {
      _snack('Could not attach that photo. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _attach(source);
  }

  void _preview(Uint8List bytes) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: InteractiveViewer(child: Image.memory(bytes)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = widget.item.photoKey;

    if (key == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _busy ? null : _pickSource,
          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
          label: const Text('Add damage photo'),
        ),
      );
    }

    final bytes = ref.watch(cartPhotoBytesProvider(key)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: bytes == null ? null : () => _preview(bytes),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              child: SizedBox(
                height: 44,
                width: 44,
                child: bytes == null
                    // Uploaded and swept from the device — the photo is safe on
                    // the server, there is just nothing local left to show.
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_outlined, size: 18),
                      )
                    : Image.memory(bytes, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Damage photo attached',
                style: theme.textTheme.bodySmall),
          ),
          IconButton(
            tooltip: 'Remove photo',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: _busy
                ? null
                : () => ref.read(cartPhotoServiceProvider).detach(widget.item),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => onChanged(qty - 1),
        ),
        Text('$qty', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(qty + 1),
        ),
      ],
    );
  }
}

class _SummaryFooter extends StatelessWidget {
  const _SummaryFooter({required this.estimate, required this.onCheckout});

  final CartEstimate estimate;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FreeDeliveryBar(estimate: estimate),
              const SizedBox(height: AppSpacing.md),
              _row(context, 'Subtotal', formatUgx(estimate.subtotal)),
              if (estimate.deliveryDiscount > 0)
                _row(context, 'Delivery', 'Free',
                    strike: formatUgx(estimate.deliveryDiscount))
              else if (estimate.deliveryFee > 0)
                _row(context, 'Delivery', formatUgx(estimate.deliveryFee)),
              const Divider(height: AppSpacing.lg2),
              _row(context, 'Estimated total', formatUgx(estimate.total),
                  bold: true),
              const SizedBox(height: 4),
              Text('Final price is set after we weigh your laundry.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: onCheckout,
                child: Text('Checkout · ${formatUgx(estimate.total)}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false, String? strike}) {
    final theme = Theme.of(context);
    final style = bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          if (strike != null) ...[
            Text(strike,
                style: theme.textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.lineThrough)),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _FreeDeliveryBar extends StatelessWidget {
  const _FreeDeliveryBar({required this.estimate});

  final CartEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (estimate.freeDeliveryThresholdUgx <= 0) return const SizedBox.shrink();
    if (estimate.freeDeliveryApplied) {
      return Row(
        children: [
          const Icon(Icons.local_shipping_outlined, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Text('Free delivery unlocked 🎉',
              style: theme.textTheme.bodySmall),
        ],
      );
    }
    final progress = estimate.freeDeliveryThresholdUgx == 0
        ? 0.0
        : (estimate.subtotal / estimate.freeDeliveryThresholdUgx).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${formatUgx(estimate.amountToFreeDeliveryUgx)} more for free delivery',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 6),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Your cart is empty',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text('Add laundry or a specialty item to get started.'),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onBrowse, child: const Text('Browse services')),
        ],
      ),
    );
  }
}
