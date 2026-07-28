import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/pricing/catalog_item.dart';
import 'package:amuwak_staff/src/orders/proof/pickup_capture_screen.dart';
import 'package:amuwak_staff/src/orders/proof/proof_photo_storage.dart';
import 'package:amuwak_staff/src/orders/proof/qr_display_widget.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/proof_events_repository.dart';

/// Online-only mode: PickupCaptureScreen takes Supabase-backed repos via its
/// constructor. These tests mock them — UI-only cases use mocks that are never
/// called; write-path cases stub `insertEvent` / `updateStatus` and verify what
/// the screen passed (replacing the old in-memory-Drift row + outbox inspection).
/// The repo's own idempotency (upsert on the proof-event PK) is its contract;
/// here we verify the *screen* reuses a cached event id across retries.
class _MockOrdersRepository extends Mock implements OrdersRepository {}

class _MockProofEventsRepository extends Mock
    implements ProofEventsRepository {}

class _ThrowingProofPhotoStorage implements ProofPhotoStorage {
  @override
  Future<String> save({
    required String orderId,
    required ProofEventType type,
    required int index,
    required List<int> bytes,
  }) async {
    throw Exception('disk full');
  }
}

const _baseOrder = LaundryOrder(
  orderId: 'AMW-0421',
  customerName: 'Jane Doe',
  serviceType: ServiceType.washAndIron,
  status: OrderStatus.pendingPickup,
  timeLabel: 'Today, 09:00',
  itemCount: 12,
  phone: '+234000',
  address: '5 Yaba',
  notes: 'Gate locked',
);

/// A mock OrdersRepository whose `updateStatus` throws on the first call and
/// succeeds thereafter — exercises the capture-screen retry path.
_MockOrdersRepository _flakyUpdateOrdersRepo() {
  final repo = _MockOrdersRepository();
  var calls = 0;
  when(() => repo.updateStatus(any(), any(),
      actorStaffId: any(named: 'actorStaffId'),
      updatedAt: any(named: 'updatedAt'))).thenAnswer((_) async {
    calls += 1;
    if (calls == 1) throw Exception('transient flake');
  });
  return repo;
}

/// Fresh mock repos with write methods stubbed to succeed.
_MockOrdersRepository _okOrdersRepo() {
  final repo = _MockOrdersRepository();
  when(() => repo.updateStatus(any(), any(),
          actorStaffId: any(named: 'actorStaffId'),
          updatedAt: any(named: 'updatedAt')))
      .thenAnswer((_) async {});
  return repo;
}

_MockProofEventsRepository _okProofRepo() {
  final repo = _MockProofEventsRepository();
  when(() => repo.insertEvent(any(),
          orderId: any(named: 'orderId'),
          actorStaffId: any(named: 'actorStaffId')))
      .thenAnswer((_) async {});
  return repo;
}

PickupCaptureScreen _buildScreen({
  required LaundryOrder order,
  required ProofPhotoStorage storage,
  required Future<List<int>?> Function() pickPhoto,
  required DateTime Function() clock,
  OrdersRepository? ordersRepo,
  ProofEventsRepository? proofEventsRepo,
}) {
  return PickupCaptureScreen(
    order: order,
    photoStorage: storage,
    pickPhoto: pickPhoto,
    clock: clock,
    ordersRepo: ordersRepo ?? _okOrdersRepo(),
    proofEventsRepo: proofEventsRepo ?? _okProofRepo(),
    actorStaffId: 's-test',
    proofEventIdGenerator: () => 'pe-test',
  );
}

Future<bool?> _pumpAndPushPickup(
  WidgetTester tester, {
  required ProofPhotoStorage storage,
  required LaundryOrder order,
  Future<List<int>?> Function()? pickPhoto,
  DateTime Function()? clock,
  OrdersRepository? ordersRepo,
  ProofEventsRepository? proofEventsRepo,
  String actorStaffId = 's-test',
  String Function()? proofEventIdGenerator,
}) async {
  final handle = _PopHandle();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  handle.result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => PickupCaptureScreen(
                        order: order,
                        photoStorage: storage,
                        pickPhoto: pickPhoto ?? () async => const [1, 2, 3, 4],
                        clock: clock ?? () => DateTime(2026, 5, 12, 9, 42),
                        ordersRepo: ordersRepo ?? _okOrdersRepo(),
                        proofEventsRepo: proofEventsRepo ?? _okProofRepo(),
                        actorStaffId: actorStaffId,
                        proofEventIdGenerator:
                            proofEventIdGenerator ?? () => 'pe-test',
                      ),
                    ),
                  );
                  handle.resolved = true;
                },
                child: const Text('Open'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  // Stash the handle on the tester via an expando-free approach: return it.
  _lastHandle = handle;
  return handle.result;
}

/// Most-recent push handle so write-path tests can read the pop result/resolved
/// flag after driving the screen.
_PopHandle? _lastHandle;

/// Scrolls the [_Stage.collecting] ListView until the 'Confirm with customer'
/// button is visible. Adding pricing widgets (weight field, line-items editor,
/// total card) made the list long enough that the button can be below the fold
/// in the default test-viewport height.
Future<void> _scrollToConfirm(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('pickup_confirm')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(ProofEvent(
      id: 'fb',
      type: ProofEventType.pickup,
      capturedAt: DateTime(2026, 1, 1),
      count: 1,
      photoPaths: const [],
    ));
    registerFallbackValue(OrderStatus.pendingPickup);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  testWidgets(
      'Confirm button is disabled until count > 0 AND at least one photo is captured',
      (tester) async {
    final storage = InMemoryProofPhotoStorage();
    await _pumpAndPushPickup(tester, storage: storage, order: _baseOrder);

    final confirmButton = find.widgetWithText(
      ElevatedButton,
      'Confirm with customer',
    );

    // Scroll to confirm first to check it is initially disabled.
    await _scrollToConfirm(tester);
    expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNull);

    // Scroll back to top to interact with count_increment / add_photo.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pump();
    await tester.tap(find.byKey(const Key('count_increment')));
    await tester.pump();

    // Still disabled (photo missing) — check after scrolling to confirm.
    await _scrollToConfirm(tester);
    expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNull);

    // Scroll back to add photo, then re-check.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add_photo')));
    await tester.pumpAndSettle();
    await _scrollToConfirm(tester);
    expect(
      tester.widget<ElevatedButton>(confirmButton).onPressed,
      isNotNull,
    );
  });

  testWidgets(
      'Tapping Done flips the order to in_progress and inserts a pickup '
      'proof event through the repos', (tester) async {
    final ordersRepo = _okOrdersRepo();
    final proofEventsRepo = _okProofRepo();
    final storage = InMemoryProofPhotoStorage();

    await _pumpAndPushPickup(
      tester,
      storage: storage,
      order: _baseOrder,
      pickPhoto: () async => const [10, 20, 30],
      ordersRepo: ordersRepo,
      proofEventsRepo: proofEventsRepo,
      proofEventIdGenerator: () => 'pe-task-11',
    );

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('add_photo')));
    await tester.pumpAndSettle();
    await _scrollToConfirm(tester);
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Confirm with customer'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tie tag to the bag'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pumpAndSettle();

    expect(_lastHandle!.result, isTrue);

    // Proof event inserted with the right id/type/count/orderId.
    final event = verify(() => proofEventsRepo.insertEvent(
          captureAny(),
          orderId: 'AMW-0421',
          actorStaffId: 's-test',
        )).captured.single as ProofEvent;
    expect(event.id, 'pe-task-11');
    expect(event.type, ProofEventType.pickup);
    expect(event.count, 12);

    // Order flipped to in_progress through the repo.
    verify(() => ordersRepo.updateStatus(
          'AMW-0421',
          OrderStatus.inProgress,
          actorStaffId: 's-test',
          updatedAt: any(named: 'updatedAt'),
        )).called(1);

    // Photo bytes were persisted to storage.
    expect(storage.savedPhotos, hasLength(1));
    expect(storage.savedPhotos.single.bytes, equals(const [10, 20, 30]));
  });

  testWidgets(
    'Tie tag to the bag shows the human order code, never the UUID order id',
    (tester) async {
      // orderId is the internal UUID v7 key; orderCode is the short code a
      // rider writes on the bag. They MUST differ here so the test can't pass
      // by the two being accidentally equal (as in the shared _baseOrder).
      const order = LaundryOrder(
        orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
        orderCode: 'AMW-2026-0042',
        customerName: 'Jane Doe',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 'Today, 09:00',
        itemCount: 12,
        phone: '+234000',
        address: '5 Yaba',
        notes: '',
      );

      await _pumpAndPushPickup(
        tester,
        storage: InMemoryProofPhotoStorage(),
        order: order,
        pickPhoto: () async => const [10, 20, 30],
      );

      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();
      await _scrollToConfirm(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tie tag to the bag'), findsOneWidget);

      // The bag instruction + displayed text both carry the short human code
      // (exactly two places — findsNWidgets(2) locks in both, so dropping
      // either one is caught).
      expect(find.textContaining('AMW-2026-0042'), findsNWidgets(2));
      // ...and the long UUID is never put in front of the rider.
      expect(
        find.textContaining('019e9147-608b-72b7-9e2c-0baa04e85094'),
        findsNothing,
      );
      // The QR encodes the order code too (the camera reads it back at delivery).
      final qr = tester.widget<QrDisplayWidget>(find.byType(QrDisplayWidget));
      expect(qr.data, 'AMW-2026-0042');
    },
  );

  testWidgets(
    'a placeholder order (no server code yet) hides the tag/QR and shows '
    'pending guidance, never a UUID to write on the bag',
    (tester) async {
      // Offline order: orderCode unset so it falls back to the UUID orderId
      // (hasServerCode false). Printing/writing this UUID on a bag would yield
      // an unscannable tag that never matches the real AMW code at delivery.
      const placeholder = LaundryOrder(
        orderId: '019e9147-608b-72b7-9e2c-0baa04e85094',
        customerName: 'Jane Doe',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 'Today, 09:00',
        itemCount: 12,
        phone: '+234000',
        address: '5 Yaba',
        notes: '',
      );

      await _pumpAndPushPickup(
        tester,
        storage: InMemoryProofPhotoStorage(),
        order: placeholder,
        pickPhoto: () async => const [10, 20, 30],
      );

      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();
      await _scrollToConfirm(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
      );
      await tester.pumpAndSettle();

      // Still on the tag stage, but no printable/scannable code exists yet.
      expect(find.text('Tie tag to the bag'), findsOneWidget);
      expect(find.byType(QrDisplayWidget), findsNothing);
      expect(find.byKey(const Key('pickup_print_tag')), findsNothing);
      // The rider is guided to the customer name, never handed the UUID.
      expect(find.textContaining('019e9147'), findsNothing);
      expect(find.textContaining('once it syncs'), findsOneWidget);
      // They can still finish the pickup.
      expect(find.widgetWithText(ElevatedButton, 'Done'), findsOneWidget);
    },
  );

  testWidgets(
    'Done re-enables itself, surfaces an error, and performs NO repo writes '
    'when photo save fails',
    (tester) async {
      final ordersRepo = _okOrdersRepo();
      final proofEventsRepo = _okProofRepo();

      await _pumpAndPushPickup(
        tester,
        storage: _ThrowingProofPhotoStorage(),
        order: _baseOrder,
        pickPhoto: () async => const [10, 20, 30],
        ordersRepo: ordersRepo,
        proofEventsRepo: proofEventsRepo,
        proofEventIdGenerator: () => 'pe-task-11',
      );

      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();
      await _scrollToConfirm(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      // Did not pop; still on QR stage; Done re-enabled; error shown.
      expect(_lastHandle!.resolved, isFalse);
      expect(_lastHandle!.result, isNull);
      expect(find.text('Tie tag to the bag'), findsOneWidget);
      final done = find.widgetWithText(ElevatedButton, 'Done');
      expect(tester.widget<ElevatedButton>(done).onPressed, isNotNull);
      expect(find.textContaining('Could not save pickup proof'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Photo-save failure short-circuited before any repo write.
      verifyNever(() => proofEventsRepo.insertEvent(any(),
          orderId: any(named: 'orderId'),
          actorStaffId: any(named: 'actorStaffId')));
      verifyNever(() => ordersRepo.updateStatus(any(), any(),
          actorStaffId: any(named: 'actorStaffId'),
          updatedAt: any(named: 'updatedAt')));
    },
  );

  testWidgets(
    'Rapid taps on add photo only trigger one pickPhoto and hide the tile',
    (tester) async {
      final completers = <Completer<List<int>?>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _baseOrder,
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () {
              final c = Completer<List<int>?>();
              completers.add(c);
              return c.future;
            },
            clock: () => DateTime(2026, 5, 12, 9, 42),
          ),
        ),
      );

      final addTile = find.byKey(const Key('add_photo'));
      for (var i = 0; i < 5; i++) {
        await tester.tap(addTile);
      }
      await tester.pump();

      expect(completers, hasLength(1));
      expect(find.byKey(const Key('add_photo')), findsNothing);

      completers.first.complete(const [1, 2, 3]);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_photo')), findsOneWidget);
      expect(completers, hasLength(1));
    },
  );

  testWidgets(
    'Captured photo thumbnail renders the bytes via MemoryImage',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _baseOrder,
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [9, 8, 7, 6, 5],
            clock: () => DateTime(2026, 5, 12, 9, 42),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);

      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(1));
      final image = images.single;
      expect(image.image, isA<MemoryImage>());
      final memoryImage = image.image as MemoryImage;
      expect(memoryImage.bytes, equals(Uint8List.fromList(const [9, 8, 7, 6, 5])));
    },
  );

  testWidgets(
    'Add photo recovers and surfaces an error when pickPhoto throws',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _baseOrder,
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async {
              throw Exception('camera permission revoked');
            },
            clock: () => DateTime(2026, 5, 12, 9, 42),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_photo')), findsOneWidget);
      expect(find.textContaining('Could not open camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Add photo surfaces a permission-specific message when camera access is denied',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _baseOrder,
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async {
              throw PlatformException(code: 'camera_access_denied');
            },
            clock: () => DateTime(2026, 5, 12, 9, 42),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_photo')), findsOneWidget);
      expect(find.textContaining('Camera permission denied'), findsOneWidget);
      expect(find.textContaining('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Add photo surfaces a device-specific message when no camera is available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _baseOrder,
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async {
              throw PlatformException(code: 'no_available_camera');
            },
            clock: () => DateTime(2026, 5, 12, 9, 42),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_photo')), findsOneWidget);
      expect(find.textContaining('No camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Retrying Done after a transient status-update failure reuses the cached '
    'proof-event id (so the repo upsert stays idempotent)',
    (tester) async {
      // Critical #2: a fresh UUID per Done-tap would land a duplicate proof
      // event on retry. The screen caches the id, so both insertEvent calls
      // use the SAME id and the repo's upsert dedupes server-side.
      final flakyOrdersRepo = _flakyUpdateOrdersRepo();
      final proofEventsRepo = _okProofRepo();

      await _pumpAndPushPickup(
        tester,
        storage: InMemoryProofPhotoStorage(),
        order: _baseOrder,
        pickPhoto: () async => const [10, 20, 30],
        ordersRepo: flakyOrdersRepo,
        proofEventsRepo: proofEventsRepo,
        proofEventIdGenerator: () => 'pe-retry-once',
      );

      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();
      await _scrollToConfirm(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
      );
      await tester.pumpAndSettle();

      // First Done — proof insert succeeds, status update throws → no pop.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();
      expect(_lastHandle!.result, isNull);
      expect(find.text('Tie tag to the bag'), findsOneWidget);
      expect(find.textContaining('status update failed'), findsOneWidget);

      // Flush the SnackBar before tapping Done again.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Second Done — status update succeeds → pops.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();
      expect(_lastHandle!.result, isTrue);

      // insertEvent was called on BOTH taps with the SAME cached id.
      final events = verify(() => proofEventsRepo.insertEvent(
            captureAny(),
            orderId: 'AMW-0421',
            actorStaffId: 's-test',
          )).captured.cast<ProofEvent>();
      expect(events, hasLength(2));
      expect(events.every((e) => e.id == 'pe-retry-once'), isTrue);

      // updateStatus attempted twice (first threw, second succeeded).
      verify(() => flakyOrdersRepo.updateStatus(
            'AMW-0421',
            OrderStatus.inProgress,
            actorStaffId: 's-test',
            updatedAt: any(named: 'updatedAt'),
          )).called(2);
    },
  );

  testWidgets(
    'Back from QR stage returns to collecting without losing count/photos/notes',
    (tester) async {
      final storage = InMemoryProofPhotoStorage();

      await _pumpAndPushPickup(
        tester,
        storage: storage,
        order: _baseOrder,
        pickPhoto: () async => const [10, 20, 30],
      );

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const Key('count_increment')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('pickup_notes')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('pickup_notes')), 'fragile silk');
      await tester.pump();

      await _scrollToConfirm(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tie tag to the bag'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(_lastHandle!.resolved, isFalse);
      expect(_lastHandle!.result, isNull);
      expect(find.text('Tie tag to the bag'), findsNothing);

      // Scroll to confirm button to verify it exists and state was preserved.
      await _scrollToConfirm(tester);
      expect(find.text('Confirm with customer'), findsOneWidget);

      // Scroll back to top to check count/photos.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Photos (1/3)'), findsOneWidget);

      // Scroll to notes field to verify it still has the entered text.
      await tester.scrollUntilVisible(
        find.byKey(const Key('pickup_notes')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('fragile silk'), findsOneWidget);
    },
  );

  testWidgets(
    'count_decrement decrements the count once it is above zero',
    (tester) async {
      // Covers the enabled decrement onPressed branch (count > 0): the button
      // is disabled at 0, then enabled and functional after an increment.
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _baseOrder,
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [1, 2, 3],
            clock: () => DateTime(2026, 5, 12, 9, 42),
          ),
        ),
      );

      final decrement = find.byKey(const Key('count_decrement'));
      // At zero the decrement is disabled.
      expect(tester.widget<IconButton>(decrement).onPressed, isNull);

      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      // Now enabled — tapping it walks the count back down.
      expect(tester.widget<IconButton>(decrement).onPressed, isNotNull);
      await tester.tap(decrement);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    },
  );

  testWidgets(
    'Removing a special line item drops it from the list and the total',
    (tester) async {
      // Covers LineItemsEditor.onRemove: add a catalog item, then remove it.
      const priced = LaundryOrder(
        orderId: 'AMW-0421',
        customerName: 'Jane Doe',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.pendingPickup,
        timeLabel: 'Today, 09:00',
        itemCount: 12,
        phone: '+234000',
        address: '5 Yaba',
        notes: '',
        ratePerKgSnapshotUgx: 5000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PickupCaptureScreen(
            order: priced,
            photoStorage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [1, 2, 3],
            clock: () => DateTime(2026, 5, 12, 9, 42),
            ordersRepo: _okOrdersRepo(),
            proofEventsRepo: _okProofRepo(),
            actorStaffId: 's-test',
            catalogItems: [
              CatalogItem(id: 'c1', name: 'Blanket', amountUgx: 8000),
            ],
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('add_line_item')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('add_line_item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pick_catalog_item_0')));
      await tester.pumpAndSettle();

      // The line item is now listed.
      expect(find.text('Blanket'), findsOneWidget);

      // Remove it via the editor's per-row remove button.
      await tester.scrollUntilVisible(
        find.byKey(const Key('remove_line_item_0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('remove_line_item_0')));
      await tester.pumpAndSettle();

      expect(find.text('Blanket'), findsNothing);
    },
  );

  testWidgets(
    'Done re-enables itself and surfaces an error when the proof-event '
    'insert fails',
    (tester) async {
      // Covers the insertEvent catch block: photo save succeeds, but the
      // proof_events write throws → no pop, Done re-enabled, error shown, and
      // the status update is never attempted.
      final ordersRepo = _okOrdersRepo();
      final proofEventsRepo = _MockProofEventsRepository();
      when(() => proofEventsRepo.insertEvent(any(),
              orderId: any(named: 'orderId'),
              actorStaffId: any(named: 'actorStaffId')))
          .thenThrow(Exception('proof insert failed'));

      await _pumpAndPushPickup(
        tester,
        storage: InMemoryProofPhotoStorage(),
        order: _baseOrder,
        pickPhoto: () async => const [10, 20, 30],
        ordersRepo: ordersRepo,
        proofEventsRepo: proofEventsRepo,
        proofEventIdGenerator: () => 'pe-insert-fail',
      );

      await tester.tap(find.byKey(const Key('count_increment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('add_photo')));
      await tester.pumpAndSettle();
      await _scrollToConfirm(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm with customer'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      // Did not pop; error shown; Done re-enabled.
      expect(_lastHandle!.resolved, isFalse);
      expect(_lastHandle!.result, isNull);
      expect(find.text('Tie tag to the bag'), findsOneWidget);
      final done = find.widgetWithText(ElevatedButton, 'Done');
      expect(tester.widget<ElevatedButton>(done).onPressed, isNotNull);
      expect(find.textContaining('Could not save pickup proof'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The proof insert failed → status update was never attempted.
      verifyNever(() => ordersRepo.updateStatus(any(), any(),
          actorStaffId: any(named: 'actorStaffId'),
          updatedAt: any(named: 'updatedAt')));
    },
  );

  testWidgets(
    'PickupCaptureScreen builds with the default wall-clock when none is '
    'injected',
    (tester) async {
      // Covers the top-level _defaultClock default for `clock`: construct the
      // screen WITHOUT passing a clock so the default tear-off is exercised.
      await tester.pumpWidget(
        MaterialApp(
          home: PickupCaptureScreen(
            order: _baseOrder,
            photoStorage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [1, 2, 3],
            ordersRepo: _okOrdersRepo(),
            proofEventsRepo: _okProofRepo(),
            actorStaffId: 's-test',
          ),
        ),
      );

      expect(find.text('Confirm pickup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Mutable holder for a pushed route's pop result + whether the push resolved.
class _PopHandle {
  bool? result;
  bool resolved = false;
}
