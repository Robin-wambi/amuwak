import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/shared/widgets/sync_status_banner.dart';
import 'package:amuwak_staff/src/sync/repository_providers.dart';
import 'package:amuwak_staff/src/sync/sync_errors_provider.dart';
import 'package:amuwak_staff/src/sync/sync_status.dart';

void main() {
  testWidgets('shows a tappable error row when there are sync errors',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    // Seed 2 outbox dead-letters so syncErrorCountProvider == 2.
    final outbox = container.read(outboxRepositoryProvider);
    for (final id in ['a', 'b']) {
      await outbox.enqueue(
        id: id, forTable: 'orders', op: 'update', rowId: id, payload: const {},
      );
      for (var i = 0; i < 6; i++) {
        await outbox.markFailed(id, 'boom');
      }
    }
    await container.read(outboxDeadLetteredProvider.future);
    await container.read(pullDeadLetteredProvider.future);

    var tapped = 0;
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SyncStatusBanner(onShowErrors: () => tapped++),
        ),
      ),
    ));
    await t.pump();

    expect(find.text('2 sync errors — tap to review'), findsOneWidget);
    await t.tap(find.text('2 sync errors — tap to review'));
    expect(tapped, 1);
  });

  testWidgets(
      'error banner still surfaces offline + pending context (Bug 2)',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final outbox = container.read(outboxRepositoryProvider);
    // 2 dead-letters → errorCount == 2.
    for (final id in ['e1', 'e2']) {
      await outbox.enqueue(
        id: id, forTable: 'orders', op: 'update', rowId: id, payload: const {},
      );
      for (var i = 0; i < 6; i++) {
        await outbox.markFailed(id, 'boom');
      }
    }
    // 3 still-pending rows → pendingCount == 3.
    for (final id in ['p1', 'p2', 'p3']) {
      await outbox.enqueue(
        id: id, forTable: 'orders', op: 'update', rowId: id, payload: const {},
      );
    }
    // Device is offline.
    container.read(onlineProvider.notifier).state = false;

    await container.read(outboxDeadLetteredProvider.future);
    await container.read(pullDeadLetteredProvider.future);
    await container.read(pendingOutboxCountProvider.future);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: SyncStatusBanner(onShowErrors: () {})),
      ),
    ));
    await t.pump();

    // The error state must NOT swallow the offline + pending context.
    expect(find.text('Offline · 3 pending · 2 sync errors — tap to review'),
        findsOneWidget);
  });

  testWidgets(
      'error banner is not falsely tappable when onShowErrors is null (Bug 4)',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final outbox = container.read(outboxRepositoryProvider);
    await outbox.enqueue(
      id: 'e1', forTable: 'orders', op: 'update', rowId: 'e1',
      payload: const {},
    );
    for (var i = 0; i < 6; i++) {
      await outbox.markFailed('e1', 'boom');
    }
    await container.read(outboxDeadLetteredProvider.future);
    await container.read(pullDeadLetteredProvider.future);

    // No onShowErrors callback supplied.
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SyncStatusBanner()),
      ),
    ));
    await t.pump();

    // The error text still shows, but both the chevron AND the "tap to
    // review" copy must be absent when there's nowhere to navigate.
    expect(find.text('1 sync error'), findsOneWidget);
    expect(find.textContaining('tap to review'), findsNothing,
        reason: 'no "tap to review" copy when the banner cannot navigate');
    expect(find.byIcon(Icons.chevron_right), findsNothing,
        reason: 'no chevron when the banner cannot navigate');
    expect(find.byType(InkWell), findsNothing,
        reason: 'no tap affordance when onShowErrors is null');
  });

  testWidgets('shows the offline banner when offline with nothing pending',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    container.read(onlineProvider.notifier).state = false;

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SyncStatusBanner()),
      ),
    ));
    await t.pump();

    expect(find.text('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('offline banner appends the pending count when uploads are queued',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final outbox = container.read(outboxRepositoryProvider);
    for (final id in ['p1', 'p2']) {
      await outbox.enqueue(
        id: id, forTable: 'orders', op: 'update', rowId: id, payload: const {},
      );
    }
    container.read(onlineProvider.notifier).state = false;
    await container.read(pendingOutboxCountProvider.future);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SyncStatusBanner()),
      ),
    ));
    await t.pump();

    expect(find.text('Offline — 2 pending'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('shows the pending-uploads banner when online with a backlog',
      (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final outbox = container.read(outboxRepositoryProvider);
    await outbox.enqueue(
      id: 'p1', forTable: 'orders', op: 'update', rowId: 'p1',
      payload: const {},
    );
    await container.read(pendingOutboxCountProvider.future);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SyncStatusBanner()),
      ),
    ));
    await t.pump();

    // Singular "upload" for a single pending row.
    expect(find.text('1 pending upload'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('hides entirely when online, no pending, no errors', (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SyncStatusBanner()),
      ),
    ));
    await t.pump();

    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.textContaining('pending'), findsNothing);
  });
}
