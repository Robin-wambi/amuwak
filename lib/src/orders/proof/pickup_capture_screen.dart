import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:amuwak_core/amuwak_core.dart';
import '../../sync/orders_repository.dart';
import '../../sync/proof_events_repository.dart';
import '../order.dart';
import '../proof_event.dart';
import '../../pricing/catalog_item.dart';
import '../customer_photo_url.dart';
import '../pricing/pricing_section.dart';
import '../widgets/customer_items_section.dart';
import '../../printing/label_printer.dart';
import '../../printing/printer_store.dart';
import 'printable_tag.dart';
import 'proof_photo_storage.dart';
import 'tag_print_view.dart';

DateTime _defaultClock() => DateTime.now();

enum _Stage { collecting, showQr }

class PickupCaptureScreen extends StatefulWidget {
  const PickupCaptureScreen({
    super.key,
    required this.order,
    required this.photoStorage,
    required this.pickPhoto,
    required this.ordersRepo,
    required this.proofEventsRepo,
    required this.actorStaffId,
    this.clock = _defaultClock,
    this.proofEventIdGenerator = defaultUuidV7,
    this.labelPrinter,
    this.printerStore,
    this.captureTag = captureTagPng,
    this.catalogItems = const [],
    this.customerPhotoUrl,
  });

  final LaundryOrder order;
  final ProofPhotoStorage photoStorage;
  final PickPhotoFn pickPhoto;
  final DateTime Function() clock;
  final OrdersRepository ordersRepo;
  final ProofEventsRepository proofEventsRepo;
  final String actorStaffId;
  final String Function() proofEventIdGenerator;

  /// Optional label printer. When null the "Print tag" action is hidden and the
  /// screen falls back to its write-the-code / scan-on-screen guidance, so a
  /// printerless site still works.
  final LabelPrinter? labelPrinter;

  /// Remembers the last printer so the rider needn't re-pick it each shift.
  final PrinterStore? printerStore;

  /// Rasterises the printable tag. Injectable so tests skip real PNG encoding.
  final TagCapturer captureTag;

  /// Active catalog items offered in the special-items "Add item" picker. Empty
  /// falls back to the free-form entry sheet.
  final List<CatalogItem> catalogItems;

  /// Signs URLs for the customer's damage photos. Null renders placeholders, so
  /// a rider with no signal still sees the declared items.
  final CustomerPhotoUrlResolver? customerPhotoUrl;

  @override
  State<PickupCaptureScreen> createState() => _PickupCaptureScreenState();
}

class _PickupCaptureScreenState extends State<PickupCaptureScreen> {
  _Stage _stage = _Stage.collecting;
  int _count = 0;
  final List<List<int>> _photoBytes = [];
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _estimatedWeightController =
      TextEditingController();
  List<LineItem> _lineItems = [];
  bool _saving = false;
  bool _pickingPhoto = false;

  // Cached across retries so re-tapping "Done" after a downstream failure
  // produces a byte-identical ProofEvent + outbox payload. With the outbox's
  // deterministic dedup key (Plan 4 Task 2) AND the proof_events row's
  // insertOrIgnore on event id, both layers absorb the retry as no-ops —
  // no UI-side `_proofPersisted` flag needed.
  //
  // [_pendingUpdatedAt] is the stable timestamp passed to
  // `ordersRepo.updateStatus(updatedAt:)`. Used in the outbox dedup key for
  // `orders:update:<id>:<updatedAt>`; without it, two retries would mint
  // distinct keys and double-enqueue.
  String? _pendingEventId;
  List<String>? _pendingPhotoPaths;
  DateTime? _pendingCapturedAt;
  DateTime? _pendingUpdatedAt;

  static const int _maxPhotos = 3;

  bool get _canConfirm =>
      _count > 0 && _photoBytes.isNotEmpty && !_saving;

  OrderTotal get _provisionalTotal => recomputeTotal(PricingInputs(
        ratePerKgUgx: widget.order.ratePerKgSnapshotUgx,
        estimatedWeightKg:
            double.tryParse(_estimatedWeightController.text.trim()),
        lineItems: _lineItems,
      ));

  String _pickPhotoErrorMessage(String code) {
    return switch (code) {
      'camera_access_denied' =>
        'Camera permission denied. Enable it in Settings to take photos.',
      'no_available_camera' => 'No camera is available on this device.',
      _ => 'Could not open camera. Please try again.',
    };
  }

  Future<void> _addPhoto() async {
    if (_photoBytes.length >= _maxPhotos || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final bytes = await widget.pickPhoto();
      if (!mounted) return;
      if (bytes != null) {
        setState(() {
          _photoBytes.add(bytes);
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_pickPhotoErrorMessage(e.code))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open camera. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _pickingPhoto = false);
      }
    }
  }

  void _onConfirm() {
    setState(() {
      _stage = _Stage.showQr;
    });
  }

  Future<void> _onDone() async {
    if (_saving) return;
    setState(() => _saving = true);

    // Capture the moment Done was tapped — BEFORE the photo-save loop, which
    // can take seconds on slow flash. `??=` so a retry preserves the first
    // attempt's timestamp.
    _pendingCapturedAt ??= widget.clock();

    // Photo save — cache the paths so retries don't re-save bytes (and don't
    // surface fresh storage errors mid-retry for already-persisted photos).
    final List<String> paths;
    try {
      paths = _pendingPhotoPaths ?? <String>[
        for (var i = 0; i < _photoBytes.length; i++)
          await widget.photoStorage.save(
            orderId: widget.order.orderId,
            type: ProofEventType.pickup,
            index: i,
            bytes: _photoBytes[i],
          ),
      ];
      _pendingPhotoPaths = paths;
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save pickup proof. Please try again.'),
        ),
      );
      return;
    }

    // Generate / reuse the event id ONCE so the proof_events row (and its
    // outbox payload) is byte-identical across retries. `_pendingCapturedAt`
    // is already cached at the top of this method.
    _pendingEventId ??= widget.proofEventIdGenerator();
    final trimmedNotes = _notesController.text.trim();
    final event = ProofEvent(
      id: _pendingEventId!,
      type: ProofEventType.pickup,
      capturedAt: _pendingCapturedAt!,
      count: _count,
      photoPaths: paths,
      notes: trimmedNotes.isEmpty ? null : trimmedNotes,
    );

    try {
      await widget.proofEventsRepo.insertEvent(
        event,
        orderId: widget.order.orderId,
        actorStaffId: widget.actorStaffId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save pickup proof. Please try again.'),
        ),
      );
      return;
    }

    // Cache the stable updatedAt for the orders-update outbox key so retries
    // dedup at the SQL layer (Plan 4 Task 2).
    _pendingUpdatedAt ??= widget.clock();
    try {
      await widget.ordersRepo.updateStatus(
        widget.order.orderId,
        OrderStatus.inProgress,
        actorStaffId: widget.actorStaffId,
        updatedAt: _pendingUpdatedAt,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pickup proof saved, but status update failed. Tap Done again to '
            'retry.',
          ),
        ),
      );
      return;
    }

    try {
      await widget.ordersRepo.updatePricing(
        widget.order.copyWith(
          status: OrderStatus.inProgress,
          estimatedWeightKg:
              double.tryParse(_estimatedWeightController.text.trim()),
          lineItems: _lineItems,
        ),
        actorStaffId: widget.actorStaffId,
      );
    } catch (e, st) {
      developer.log(
        'updatePricing best-effort failed at pickup; staff can correct on the '
        'details screen.',
        name: 'PickupCaptureScreen',
        error: e,
        stackTrace: st,
      );
      // Status already advanced, so we still close — but surface the gap. The
      // snackbar uses the app-root ScaffoldMessenger, so it survives the pop
      // and shows on the screen the rider lands on.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Pickup confirmed, but pricing wasn't saved — add the weight and "
              'any line items on the order.',
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.pop<bool>(context, true);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _estimatedWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage == _Stage.collecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_stage == _Stage.showQr) {
          setState(() => _stage = _Stage.collecting);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          title: Text(
            _stage == _Stage.collecting ? 'Confirm pickup' : 'Tag the bag',
          ),
        ),
        body: SafeArea(
          child: _stage == _Stage.collecting
              ? _buildCollecting()
              : _buildQrStage(),
        ),
      ),
    );
  }

  Widget _buildCollecting() {
    final provisional = _provisionalTotal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          widget.order.customerName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          'Expected ${widget.order.itemCount} items · ${widget.order.address}',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        // What the customer declared in their cart, before the rider counts —
        // including photos of anything they flagged as already damaged.
        if (widget.order.cartItems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          CustomerItemsSection(
            items: widget.order.cartItems,
            photoUrl: widget.customerPhotoUrl,
            title: 'Customer declared',
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'How many items?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key('count_decrement'),
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _count > 0
                  ? () => setState(() => _count--)
                  : null,
            ),
            SizedBox(
              width: 60,
              child: Text(
                '$_count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              key: const Key('count_increment'),
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => _count++),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Photos (${_photoBytes.length}/$_maxPhotos)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _photoBytes.length; i++)
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.field),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  Uint8List.fromList(_photoBytes[i]),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_outlined),
                ),
              ),
            if (_photoBytes.length < _maxPhotos && !_pickingPhoto)
              GestureDetector(
                key: const Key('add_photo'),
                onTap: _addPhoto,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                  child: Icon(
                    Icons.add_a_photo_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Estimated weight (kg)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('pickup_estimated_weight'),
          controller: _estimatedWeightController,
          decoration: const InputDecoration(
            labelText: 'Estimated weight (kg)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Text(
          'Special items',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LineItemsEditor(
          items: _lineItems,
          onAdd: () async {
            final item =
                await showPickLineItemSheet(context, widget.catalogItems);
            if (item != null) {
              setState(() => _lineItems = [..._lineItems, item]);
            }
          },
          onRemove: (index) {
            setState(() {
              final updated = List<LineItem>.from(_lineItems);
              updated.removeAt(index);
              _lineItems = updated;
            });
          },
        ),
        const SizedBox(height: 12),
        TotalCard(
          totalUgx: provisional.total,
          isProvisional: provisional.isProvisional,
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: const Key('pickup_notes'),
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('pickup_confirm'),
          onPressed: _canConfirm ? _onConfirm : null,
          child: const Text('Confirm with customer'),
        ),
      ],
    );
  }

  Widget _buildQrStage() {
    final canPrint = widget.labelPrinter != null;
    // An order created offline has no server-minted AMW code yet (its orderCode
    // is still the UUID placeholder). Printing/writing that UUID would produce
    // an unscannable tag that never matches the real code assigned at delivery,
    // so gate the whole tag/QR/print workflow until the code backfills.
    final hasCode = widget.order.hasServerCode;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    'Tie tag to the bag',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (hasCode) ...[
                    Text(
                      canPrint
                          ? 'Print the tag and tie it to the bag, or write order '
                              '#${widget.order.orderCode} on it.'
                          : 'Write order #${widget.order.orderCode} on the bag, '
                              'or scan this QR.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 24),
                    TagPrintView(
                      orderCode: widget.order.orderCode,
                      customerName: widget.order.customerName,
                      labelPrinter: widget.labelPrinter,
                      printerStore: widget.printerStore,
                      captureTag: widget.captureTag,
                      buttonKey: const Key('pickup_print_tag'),
                    ),
                  ] else
                    Text(
                      "This order's code is assigned once it syncs. For now, tie "
                      'a blank tag and identify the bag by the customer name '
                      '(${widget.order.customerName}). Print or write the code '
                      'after it syncs.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
