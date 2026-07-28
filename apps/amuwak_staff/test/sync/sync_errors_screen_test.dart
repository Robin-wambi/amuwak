import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/outbox_repository.dart';
import 'package:amuwak_staff/src/sync/pull_dead_letter_repository.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';
import 'package:amuwak_staff/src/sync/sync_errors_provider.dart';
import 'package:amuwak_staff/src/sync/sync_errors_screen.dart';

class _MockOutboxRepo extends Mock implements OutboxRepository {}

class _MockPullRepo extends Mock implements PullDeadLetterRepository {}

/// Stub `OutboxData` row — we only assert against forTable / op / rowId /
/// lastError / id, so the rest are sensible defaults.
OutboxData _stubOutboxRow({
  required String id,
  required String forTable,
  required String op,
  required String rowId,
  String? lastError,
}) {
  return OutboxData(
    id: id,
    forTable: forTable,
    op: op,
    rowId: rowId,
    payloadJson: '{}',
    createdAt: DateTime.utc(2026, 5, 23),
    retryCount: 6,
    lastAttemptedAt: DateTime.utc(2026, 5, 23, 12),
    lastError: lastError,
    status: 'dead_letter',
  );
}

PullDeadLetterData _stubPullRow({
  required String id,
  required String forTable,
  required String errorText,
}) {
  return PullDeadLetterData(
    id: id,
    forTable: forTable,
    rowPayloadJson: '{}',
    errorText: errorText,
    recordedAt: DateTime.utc(2026, 5, 23),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<OutboxData> outboxRows,
  required List<PullDeadLetterData> pullRows,
  OutboxRepository? outboxRepoOverride,
  PullDeadLetterRepository? pullRepoOverride,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        outboxDeadLetteredProvider.overrideWith(
          (ref) => Stream<List<OutboxData>>.value(outboxRows),
        ),
        pullDeadLetteredProvider.overrideWith(
          (ref) => Stream<List<PullDeadLetterData>>.value(pullRows),
        ),
        if (outboxRepoOverride != null)
          outboxRepositoryProvider.overrideWithValue(outboxRepoOverride),
        if (pullRepoOverride != null)
          pullDeadLetterRepositoryProvider
              .overrideWithValue(pullRepoOverride),
      ],
      child: const MaterialApp(home: SyncErrorsScreen()),
    ),
  );
}

void main() {
  testWidgets(
    'renders the empty-state message when there are no errors',
    (tester) async {
      await _pumpScreen(tester, outboxRows: const [], pullRows: const []);
      await tester.pumpAndSettle();

      expect(find.text('No sync errors.'), findsOneWidget);
    },
  );

  testWidgets(
    'renders outbox dead-letter rows with a Retry button that requeues',
    (tester) async {
      final mockOutbox = _MockOutboxRepo();
      when(() => mockOutbox.watchDeadLettered()).thenAnswer(
        (_) => Stream<List<OutboxData>>.value([
          _stubOutboxRow(
            id: 'k-1',
            forTable: 'orders',
            op: 'update',
            rowId: 'AMW-A',
            lastError: '23505: duplicate key value',
          ),
        ]),
      );
      when(() => mockOutbox.requeue(any())).thenAnswer((_) async {});

      await _pumpScreen(
        tester,
        outboxRows: [
          _stubOutboxRow(
            id: 'k-1',
            forTable: 'orders',
            op: 'update',
            rowId: 'AMW-A',
            lastError: '23505: duplicate key value',
          ),
        ],
        pullRows: const [],
        outboxRepoOverride: mockOutbox,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('AMW-A'), findsOneWidget);
      expect(find.text('Already saved on the server.'), findsOneWidget);
      expect(find.textContaining('23505'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pump();

      verify(() => mockOutbox.requeue('k-1')).called(1);
    },
  );

  testWidgets(
      'outbox tile Discard confirms then calls discard', (tester) async {
    final mockOutbox = _MockOutboxRepo();
    when(() => mockOutbox.discard(any())).thenAnswer((_) async {});

    await _pumpScreen(
      tester,
      outboxRows: [
        _stubOutboxRow(
          id: 'k-1', forTable: 'orders', op: 'update', rowId: 'AMW-A',
          lastError: '23505: duplicate key value',
        ),
      ],
      pullRows: const [],
      outboxRepoOverride: mockOutbox,
    );
    await tester.pumpAndSettle();

    // Friendly text replaces the raw "23505: ..." string.
    expect(find.text('Already saved on the server.'), findsOneWidget);
    expect(find.textContaining('23505'), findsNothing);

    // The tile's 'Discard' opens a confirm dialog; the dialog's
    // 'Discard upload' action is what calls repo.discard.
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Discard upload'));
    await tester.pumpAndSettle();

    verify(() => mockOutbox.discard('k-1')).called(1);
  });

  testWidgets(
      'outbox tile Discard then Cancel dismisses the dialog without discarding',
      (tester) async {
    // Covers the dialog's Cancel action (pop(false)) and the `ok != true`
    // early-return guard: discard must NOT be called.
    final mockOutbox = _MockOutboxRepo();
    when(() => mockOutbox.discard(any())).thenAnswer((_) async {});

    await _pumpScreen(
      tester,
      outboxRows: [
        _stubOutboxRow(
          id: 'k-1', forTable: 'orders', op: 'update', rowId: 'AMW-A',
          lastError: '23505: duplicate key value',
        ),
      ],
      pullRows: const [],
      outboxRepoOverride: mockOutbox,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard upload?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Dialog gone and no discard happened.
    expect(find.text('Discard upload?'), findsNothing);
    verifyNever(() => mockOutbox.discard(any()));
  });

  testWidgets(
    'a failing discard surfaces a SnackBar instead of being swallowed',
    (tester) async {
      // Covers the discard catch block: a confirmed discard whose repo call
      // throws shows rider-friendly copy, not the raw exception.
      final mockOutbox = _MockOutboxRepo();
      when(() => mockOutbox.discard(any()))
          .thenThrow(StateError('local drift delete failed'));

      await _pumpScreen(
        tester,
        outboxRows: [
          _stubOutboxRow(
            id: 'k-1', forTable: 'orders', op: 'update', rowId: 'AMW-A',
            lastError: 'network down',
          ),
        ],
        pullRows: const [],
        outboxRepoOverride: mockOutbox,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Discard upload'));
      // Pump for the async discard + SnackBar animation.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Could not discard'), findsOneWidget);
      expect(find.textContaining('drift delete failed'), findsNothing);
    },
  );

  testWidgets(
    'a failing requeue surfaces a SnackBar instead of being swallowed',
    (tester) async {
      final mockOutbox = _MockOutboxRepo();
      when(() => mockOutbox.requeue(any()))
          .thenThrow(StateError('local drift write failed'));

      await _pumpScreen(
        tester,
        outboxRows: [
          _stubOutboxRow(
            id: 'k-1',
            forTable: 'orders',
            op: 'update',
            rowId: 'AMW-A',
            lastError: 'network down',
          ),
        ],
        pullRows: const [],
        outboxRepoOverride: mockOutbox,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      // Pump enough for the async retry + SnackBar animation to settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Could not retry'), findsOneWidget);
      // The raw exception must not leak into rider-facing copy.
      expect(find.textContaining('drift write failed'), findsNothing);
    },
  );

  testWidgets(
    'renders pull dead-letter rows with no Retry button (server-side fix)',
    (tester) async {
      await _pumpScreen(
        tester,
        outboxRows: const [],
        pullRows: [
          _stubPullRow(
            id: 'orders:AMW-Z:123',
            forTable: 'orders',
            errorText: 'TypeError: null is not a String',
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('orders'), findsWidgets);
      // Pull errors get rider-readable copy too; the raw exception is hidden.
      expect(find.text('Server data could not be loaded — needs a fix '
          'on the server.'), findsOneWidget);
      expect(find.textContaining('TypeError'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
      expect(find.text('Server fix required'), findsOneWidget);
    },
  );

  testWidgets(
    'pull dead-letter tile has a Dismiss button that deletes the row',
    (tester) async {
      final mockPull = _MockPullRepo();
      when(() => mockPull.delete(any())).thenAnswer((_) async {});

      await _pumpScreen(
        tester,
        outboxRows: const [],
        pullRows: [
          _stubPullRow(
            id: 'orders:AMW-Z:123',
            forTable: 'orders',
            errorText: 'TypeError: null is not a String',
          ),
        ],
        pullRepoOverride: mockPull,
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Dismiss'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
      await tester.pump();

      verify(() => mockPull.delete('orders:AMW-Z:123')).called(1);
    },
  );

  testWidgets(
    'a failing dismiss surfaces a SnackBar instead of being swallowed',
    (tester) async {
      final mockPull = _MockPullRepo();
      when(() => mockPull.delete(any()))
          .thenThrow(StateError('local drift delete failed'));

      await _pumpScreen(
        tester,
        outboxRows: const [],
        pullRows: [
          _stubPullRow(
            id: 'orders:AMW-Z:123',
            forTable: 'orders',
            errorText: 'TypeError: null is not a String',
          ),
        ],
        pullRepoOverride: mockPull,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
      // Pump enough for the async delete + SnackBar animation to settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Could not dismiss'), findsOneWidget);
      // The raw exception must not leak into rider-facing copy.
      expect(find.textContaining('drift delete failed'), findsNothing);
    },
  );

  testWidgets(
    'outbox tile with a long rowId does not overflow on a narrow screen',
    (tester) async {
      // Guard against the trailing Retry+Discard buttons colliding with a long
      // title on a small phone. A RenderFlex overflow throws during layout and
      // is captured by tester.takeException.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpScreen(
        tester,
        outboxRows: [
          _stubOutboxRow(
            id: 'k-long',
            forTable: 'order_status_events',
            op: 'update',
            rowId: '8f14e45f-ceea-467a-9f4e-1a2b3c4d5e6f',
            lastError: 'boom',
          ),
        ],
        pullRows: const [],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the tile must lay out without a RenderFlex overflow');
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Discard'), findsOneWidget);
    },
  );

  testWidgets(
    'outbox tile title ellipsizes a long rowId instead of wrapping',
    (tester) async {
      // The title carries a UUID rowId; without a maxLines cap it wraps to
      // several lines on a narrow phone, leaving a ragged multi-line tile next
      // to the Retry/Discard buttons. It should ellipsize to a single line.
      await _pumpScreen(
        tester,
        outboxRows: [
          _stubOutboxRow(
            id: 'k-long',
            forTable: 'order_status_events',
            op: 'update',
            rowId: '8f14e45f-ceea-467a-9f4e-1a2b3c4d5e6f',
            lastError: 'boom',
          ),
        ],
        pullRows: const [],
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(
        find.textContaining('8f14e45f-ceea-467a-9f4e-1a2b3c4d5e6f'),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'outbox load failure shows friendly copy, not the raw exception',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outboxDeadLetteredProvider.overrideWith(
              (ref) => Stream<List<OutboxData>>.error(
                StateError('drift read failed'),
              ),
            ),
            pullDeadLetteredProvider.overrideWith(
              (ref) => Stream<List<PullDeadLetterData>>.value(const []),
            ),
          ],
          child: const MaterialApp(home: SyncErrorsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load sync errors — please try again.'),
          findsOneWidget);
      expect(find.textContaining('drift read failed'), findsNothing);
    },
  );

  testWidgets(
    'pull load failure shows friendly copy, not the raw exception',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outboxDeadLetteredProvider.overrideWith(
              (ref) => Stream<List<OutboxData>>.value(const []),
            ),
            pullDeadLetteredProvider.overrideWith(
              (ref) => Stream<List<PullDeadLetterData>>.error(
                StateError('drift read failed'),
              ),
            ),
          ],
          child: const MaterialApp(home: SyncErrorsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load sync errors — please try again.'),
          findsOneWidget);
      expect(find.textContaining('drift read failed'), findsNothing);
    },
  );
}
