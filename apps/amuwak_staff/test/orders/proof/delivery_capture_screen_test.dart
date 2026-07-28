import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/orders/order.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/orders/proof/delivery_capture_screen.dart';
import 'package:amuwak_staff/src/orders/proof/proof_photo_storage.dart';
import 'package:amuwak_staff/src/orders/proof_event.dart';
import 'package:amuwak_staff/src/sync/orders_repository.dart';
import 'package:amuwak_staff/src/sync/proof_events_repository.dart';

/// Online-only mode: DeliveryCaptureScreen takes Supabase-backed repos via its
/// constructor. These tests mock them — UI-only cases use mocks that are never
/// called; write-path cases stub `insertEvent` / `updateStatus` and verify what
/// the screen passed. The repo's own idempotency (upsert on the proof-event PK)
/// is its contract; here we verify the *screen* reuses a cached event id across
/// retries (so the repo upsert dedupes).
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

LaundryOrder _orderReadyForDelivery() {
  return LaundryOrder(
    orderId: 'AMW-0421',
    customerName: 'Jane Doe',
    serviceType: ServiceType.washAndIron,
    status: OrderStatus.readyForDelivery,
    timeLabel: 'Today, 16:00',
    itemCount: 12,
    phone: '+234000',
    address: '5 Yaba',
    notes: '',
    proofEvents: [
      ProofEvent(
        id: 'pe-test-1',
        type: ProofEventType.pickup,
        capturedAt: DateTime(2026, 5, 12, 9, 42),
        count: 12,
        photoPaths: const ['memory://AMW-0421/pickup_0'],
      ),
    ],
  );
}

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

DeliveryCaptureScreen _buildScreen({
  required LaundryOrder order,
  required ProofPhotoStorage storage,
  required Future<List<int>?> Function() pickPhoto,
  required DateTime Function() clock,
  OrdersRepository? ordersRepo,
  ProofEventsRepository? proofEventsRepo,
}) {
  return DeliveryCaptureScreen(
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

Future<void> _pumpAndPushDelivery(
  WidgetTester tester, {
  required ProofPhotoStorage storage,
  required LaundryOrder order,
  Future<List<int>?> Function()? pickPhoto,
  DateTime Function()? clock,
  OrdersRepository? ordersRepo,
  ProofEventsRepository? proofEventsRepo,
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
                      builder: (_) => DeliveryCaptureScreen(
                        order: order,
                        photoStorage: storage,
                        pickPhoto: pickPhoto ?? () async => const [50, 60, 70],
                        clock: clock ?? () => DateTime(2026, 5, 12, 16, 13),
                        ordersRepo: ordersRepo ?? _okOrdersRepo(),
                        proofEventsRepo: proofEventsRepo ?? _okProofRepo(),
                        actorStaffId: 's-test',
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
  _lastHandle = handle;
}

_PopHandle? _lastHandle;

void main() {
  setUpAll(() {
    registerFallbackValue(ProofEvent(
      id: 'fb',
      type: ProofEventType.delivery,
      capturedAt: DateTime(2026, 1, 1),
      count: 1,
      photoPaths: const [],
    ));
    registerFallbackValue(OrderStatus.readyForDelivery);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  testWidgets('Mark delivered is disabled until a handover photo is captured',
      (tester) async {
    final storage = InMemoryProofPhotoStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: _buildScreen(
          order: _orderReadyForDelivery(),
          storage: storage,
          pickPhoto: () async => const [1, 2, 3],
          clock: () => DateTime(2026, 5, 12, 16, 13),
        ),
      ),
    );

    final button = find.widgetWithText(ElevatedButton, 'Mark delivered');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    expect(find.text('Pickup count: 12'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_handover_photo')));
    await tester.pumpAndSettle();

    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
  });

  testWidgets(
      'Tapping Mark delivered flips the order to completed and inserts a '
      'delivery proof event through the repos', (tester) async {
    final ordersRepo = _okOrdersRepo();
    final proofEventsRepo = _okProofRepo();
    final storage = InMemoryProofPhotoStorage();

    await _pumpAndPushDelivery(
      tester,
      storage: storage,
      order: _orderReadyForDelivery(),
      pickPhoto: () async => const [50, 60, 70],
      ordersRepo: ordersRepo,
      proofEventsRepo: proofEventsRepo,
      proofEventIdGenerator: () => 'pe-task-12',
    );

    await tester.tap(find.byKey(const Key('add_handover_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Mark delivered'));
    await tester.pumpAndSettle();

    expect(_lastHandle!.result, isTrue);

    final event = verify(() => proofEventsRepo.insertEvent(
          captureAny(),
          orderId: 'AMW-0421',
          actorStaffId: 's-test',
        )).captured.single as ProofEvent;
    expect(event.id, 'pe-task-12');
    expect(event.type, ProofEventType.delivery);
    expect(event.count, 12);

    verify(() => ordersRepo.updateStatus(
          'AMW-0421',
          OrderStatus.completed,
          actorStaffId: 's-test',
          updatedAt: any(named: 'updatedAt'),
        )).called(1);

    expect(storage.savedPhotos, hasLength(1));
    expect(storage.savedPhotos.single.bytes, equals(const [50, 60, 70]));
  });

  testWidgets(
    'after delivery, offers the change calculator and records the collection',
    (tester) async {
      final ordersRepo = _okOrdersRepo();
      when(() => ordersRepo.updatePayment(any(), any(),
          actorStaffId: any(named: 'actorStaffId'))).thenAnswer((_) async {});
      final proofEventsRepo = _okProofRepo();

      await _pumpAndPushDelivery(
        tester,
        storage: InMemoryProofPhotoStorage(),
        // A 10,000 bill with nothing collected yet → 10,000 outstanding.
        order: _orderReadyForDelivery().copyWith(totalUgx: 10000),
        pickPhoto: () async => const [50, 60, 70],
        ordersRepo: ordersRepo,
        proofEventsRepo: proofEventsRepo,
      );

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark delivered'));
      await tester.pumpAndSettle();

      // Delivery succeeded but hasn't popped — the change calculator is shown.
      expect(find.byKey(const Key('cash_tendered')), findsOneWidget);
      expect(_lastHandle!.result, isNull);

      await tester.enterText(find.byKey(const Key('cash_tendered')), '10000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('record_payment_confirm')));
      await tester.pumpAndSettle();

      verify(() => ordersRepo.updatePayment('AMW-0421', 10000,
          actorStaffId: 's-test')).called(1);
      // Once the sheet closes, the delivery flow pops with success.
      expect(_lastHandle!.result, isTrue);
    },
  );

  testWidgets(
    'Mark delivered re-enables itself, surfaces an error, and performs NO repo '
    'writes when photo save fails',
    (tester) async {
      final ordersRepo = _okOrdersRepo();
      final proofEventsRepo = _okProofRepo();

      await _pumpAndPushDelivery(
        tester,
        storage: _ThrowingProofPhotoStorage(),
        order: _orderReadyForDelivery(),
        pickPhoto: () async => const [50, 60, 70],
        ordersRepo: ordersRepo,
        proofEventsRepo: proofEventsRepo,
        proofEventIdGenerator: () => 'pe-task-12',
      );

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark delivered'));
      await tester.pumpAndSettle();

      expect(_lastHandle!.resolved, isFalse);
      expect(_lastHandle!.result, isNull);
      expect(find.byType(DeliveryCaptureScreen), findsOneWidget);
      final markDelivered =
          find.widgetWithText(ElevatedButton, 'Mark delivered');
      expect(tester.widget<ElevatedButton>(markDelivered).onPressed, isNotNull);
      expect(
          find.textContaining('Could not save delivery proof'), findsOneWidget);
      expect(tester.takeException(), isNull);

      verifyNever(() => proofEventsRepo.insertEvent(any(),
          orderId: any(named: 'orderId'),
          actorStaffId: any(named: 'actorStaffId')));
      verifyNever(() => ordersRepo.updateStatus(any(), any(),
          actorStaffId: any(named: 'actorStaffId'),
          updatedAt: any(named: 'updatedAt')));
    },
  );

  testWidgets(
    'Retrying Mark delivered after a transient status-update failure reuses '
    'the cached proof-event id (so the repo upsert stays idempotent)',
    (tester) async {
      // Critical #2: a fresh UUID per tap would land a duplicate delivery
      // proof on retry. The screen caches the id, so both insertEvent calls use
      // the SAME id and the repo's upsert dedupes server-side.
      final flakyOrdersRepo = _flakyUpdateOrdersRepo();
      final proofEventsRepo = _okProofRepo();

      await _pumpAndPushDelivery(
        tester,
        storage: InMemoryProofPhotoStorage(),
        order: _orderReadyForDelivery(),
        pickPhoto: () async => const [50, 60, 70],
        ordersRepo: flakyOrdersRepo,
        proofEventsRepo: proofEventsRepo,
        proofEventIdGenerator: () => 'pe-retry-once',
      );

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();

      // First Mark delivered — proof insert succeeds, status update throws.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark delivered'));
      await tester.pumpAndSettle();
      expect(_lastHandle!.result, isNull);
      expect(find.byType(DeliveryCaptureScreen), findsOneWidget);
      expect(find.textContaining('status update failed'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Second tap — status update succeeds → pops.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark delivered'));
      await tester.pumpAndSettle();
      expect(_lastHandle!.result, isTrue);

      // insertEvent was called on BOTH taps with the SAME cached id (the repo
      // upsert dedupes); updateStatus was attempted twice.
      final events = verify(() => proofEventsRepo.insertEvent(
            captureAny(),
            orderId: 'AMW-0421',
            actorStaffId: 's-test',
          )).captured.cast<ProofEvent>();
      expect(events, hasLength(2));
      expect(events.every((e) => e.id == 'pe-retry-once'), isTrue);

      verify(() => flakyOrdersRepo.updateStatus(
            'AMW-0421',
            OrderStatus.completed,
            actorStaffId: 's-test',
            updatedAt: any(named: 'updatedAt'),
          )).called(2);
    },
  );

  testWidgets(
    'Delivery falls back to itemCount when the order has no pickup proof',
    (tester) async {
      final proofEventsRepo = _okProofRepo();

      const orderWithoutPickup = LaundryOrder(
        orderId: 'AMW-0999',
        customerName: 'No Pickup',
        serviceType: ServiceType.washAndIron,
        status: OrderStatus.readyForDelivery,
        timeLabel: 'Today, 16:00',
        itemCount: 7,
        phone: '+234000',
        address: '5 Yaba',
        notes: '',
      );

      await _pumpAndPushDelivery(
        tester,
        storage: InMemoryProofPhotoStorage(),
        order: orderWithoutPickup,
        pickPhoto: () async => const [50, 60, 70],
        proofEventsRepo: proofEventsRepo,
        proofEventIdGenerator: () => 'pe-task-12b',
      );

      expect(find.text('No pickup proof on file.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark delivered'));
      await tester.pumpAndSettle();

      // Delivery proof carries itemCount (7) because pickupProof was null.
      final event = verify(() => proofEventsRepo.insertEvent(
            captureAny(),
            orderId: 'AMW-0999',
            actorStaffId: 's-test',
          )).captured.single as ProofEvent;
      expect(event.count, 7);
    },
  );

  testWidgets(
    'Captured handover photo thumbnail renders the bytes via MemoryImage',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _orderReadyForDelivery(),
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [11, 22, 33, 44],
            clock: () => DateTime(2026, 5, 12, 16, 13),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(1));
      final memoryImage = images.single.image as MemoryImage;
      expect(memoryImage.bytes, equals(Uint8List.fromList(const [11, 22, 33, 44])));
    },
  );

  testWidgets(
    'Add handover photo recovers and surfaces an error when pickPhoto throws',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _orderReadyForDelivery(),
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async {
              throw Exception('camera permission revoked');
            },
            clock: () => DateTime(2026, 5, 12, 16, 13),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_handover_photo')), findsOneWidget);
      expect(find.textContaining('Could not open camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Add handover photo surfaces a permission-specific message when camera access is denied',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _orderReadyForDelivery(),
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async {
              throw PlatformException(code: 'camera_access_denied');
            },
            clock: () => DateTime(2026, 5, 12, 16, 13),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_handover_photo')), findsOneWidget);
      expect(find.textContaining('Camera permission denied'), findsOneWidget);
      expect(find.textContaining('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Add handover photo surfaces a device-specific message when no camera is available',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _orderReadyForDelivery(),
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () async {
              throw PlatformException(code: 'no_available_camera');
            },
            clock: () => DateTime(2026, 5, 12, 16, 13),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_handover_photo')), findsOneWidget);
      expect(find.textContaining('No camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Rapid taps on add handover photo only trigger one pickPhoto and hide the tile',
    (tester) async {
      final completers = <Completer<List<int>?>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: _buildScreen(
            order: _orderReadyForDelivery(),
            storage: InMemoryProofPhotoStorage(),
            pickPhoto: () {
              final c = Completer<List<int>?>();
              completers.add(c);
              return c.future;
            },
            clock: () => DateTime(2026, 5, 12, 16, 13),
          ),
        ),
      );

      final addTile = find.byKey(const Key('add_handover_photo'));
      for (var i = 0; i < 5; i++) {
        await tester.tap(addTile);
      }
      await tester.pump();

      expect(completers, hasLength(1));
      expect(find.byKey(const Key('add_handover_photo')), findsNothing);

      completers.first.complete(const [4, 5, 6]);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_handover_photo')), findsOneWidget);
      expect(completers, hasLength(1));
    },
  );

  testWidgets(
    'Mark delivered re-enables itself and surfaces an error when the '
    'proof-event insert fails',
    (tester) async {
      // Covers the insertEvent catch block: photo save succeeds, the
      // proof_events write throws → no pop, button re-enabled, error shown, and
      // updateStatus is never attempted.
      final ordersRepo = _okOrdersRepo();
      final proofEventsRepo = _MockProofEventsRepository();
      when(() => proofEventsRepo.insertEvent(any(),
              orderId: any(named: 'orderId'),
              actorStaffId: any(named: 'actorStaffId')))
          .thenThrow(Exception('proof insert failed'));

      await _pumpAndPushDelivery(
        tester,
        storage: InMemoryProofPhotoStorage(),
        order: _orderReadyForDelivery(),
        pickPhoto: () async => const [50, 60, 70],
        ordersRepo: ordersRepo,
        proofEventsRepo: proofEventsRepo,
        proofEventIdGenerator: () => 'pe-insert-fail',
      );

      await tester.tap(find.byKey(const Key('add_handover_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark delivered'));
      await tester.pumpAndSettle();

      expect(_lastHandle!.resolved, isFalse);
      expect(_lastHandle!.result, isNull);
      expect(find.byType(DeliveryCaptureScreen), findsOneWidget);
      final markDelivered =
          find.widgetWithText(ElevatedButton, 'Mark delivered');
      expect(tester.widget<ElevatedButton>(markDelivered).onPressed, isNotNull);
      expect(
          find.textContaining('Could not save delivery proof'), findsOneWidget);
      expect(tester.takeException(), isNull);

      verifyNever(() => ordersRepo.updateStatus(any(), any(),
          actorStaffId: any(named: 'actorStaffId'),
          updatedAt: any(named: 'updatedAt')));
    },
  );

  testWidgets(
    'DeliveryCaptureScreen builds with the default wall-clock when none is '
    'injected',
    (tester) async {
      // Covers the top-level _defaultClock default for `clock`.
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryCaptureScreen(
            order: _orderReadyForDelivery(),
            photoStorage: InMemoryProofPhotoStorage(),
            pickPhoto: () async => const [1, 2, 3],
            ordersRepo: _okOrdersRepo(),
            proofEventsRepo: _okProofRepo(),
            actorStaffId: 's-test',
          ),
        ),
      );

      expect(find.text('Hand over'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Mutable holder for a pushed route's pop result + whether the push resolved.
class _PopHandle {
  bool? result;
  bool resolved = false;
}
