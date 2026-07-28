import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:amuwak_staff/main.dart';
import 'package:amuwak_staff/src/auth/login_screen.dart';
import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_staff/src/data/app_database.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator.dart';
import 'package:amuwak_staff/src/sync/sync_orchestrator_provider.dart';
import 'package:amuwak_staff/src/sync/sync_status.dart';

class _MockOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 5));
  });

  late AppDatabase db;
  late _MockOrchestrator orchestrator;
  late StreamController<AuthState> authController;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    orchestrator = _MockOrchestrator();
    when(() => orchestrator.start()).thenAnswer((_) async {});
    when(() => orchestrator.stop()).thenAnswer((_) async {});
    authController = StreamController<AuthState>.broadcast();
  });

  tearDown(() async {
    await authController.close();
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncOrchestratorProvider.overrideWithValue(orchestrator),
          authStateProvider.overrideWith((ref) => authController.stream),
          // AuthGate reads these; pin them to "signed out" so it renders
          // LoginScreen without touching the uninitialised Supabase.instance
          // (currentUserIdProvider otherwise falls back to
          // authServiceProvider.currentUser). The orchestrator start/stop
          // assertions below drive off authStateProvider, not these.
          currentUserIdProvider.overrideWithValue(null),
          currentAuthEventProvider.overrideWithValue(null),
        ],
        child: const AmuwakStaffApp(),
      ),
    );
    await tester.pump();
  }

  testWidgets('app renders login screen on a signed-out container without throwing',
      (tester) async {
    await pumpApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'syncLifecycleProvider is mounted at startup — '
    'an emitted signed-in AuthState triggers orchestrator.start()',
    (tester) async {
      await pumpApp(tester);

      // No start() yet — no signed-in event has been emitted.
      verifyNever(() => orchestrator.start());

      // Emit a signed-in AuthState. We rely on the listener inside
      // syncLifecycleProvider being installed during app build; if the
      // consumer isn't wired in main.dart, start() will never fire.
      final session = Session(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'bearer',
        user: User(
          id: 'u-1',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.utc(2026, 5, 19).toIso8601String(),
        ),
      );
      authController.add(AuthState(AuthChangeEvent.signedIn, session));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      verify(() => orchestrator.start()).called(1);
    },
  );

  testWidgets(
    'a signed-in → signed-out transition triggers orchestrator.stop()',
    (tester) async {
      await pumpApp(tester);

      final session = Session(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'bearer',
        user: User(
          id: 'u-1',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.utc(2026, 5, 19).toIso8601String(),
        ),
      );
      authController.add(AuthState(AuthChangeEvent.signedIn, session));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      verify(() => orchestrator.start()).called(1);

      authController.add(AuthState(AuthChangeEvent.signedOut, null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      verify(() => orchestrator.stop()).called(1);
    },
  );
}
