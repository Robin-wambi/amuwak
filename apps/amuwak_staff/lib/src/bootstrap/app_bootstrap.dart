import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import '../data/orders_seeder.dart';
import 'timeout_http_client.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = AppConfig.fromEnvironment()..validate();
    // Cap every PostgREST/RPC/Storage/Auth call so a poor or dead network fails
    // fast (TimeoutException) instead of hanging the rider indefinitely. This is
    // the online-only-mode resilience win; it also survives into offline mode,
    // where the puller and any online RPC keep using it.
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      httpClient: TimeoutHttpClient(http.Client()),
    );
    // Both apps share one auth project and therefore one recovery email
    // template, so the token-hash link shape reaches staff too — without this
    // a rider's reset link would land here and do nothing at all. Verifying
    // raises `passwordRecovery`, which AuthGate seeds from; the event survives
    // firing this early because GoTrue's auth stream replays its last value to
    // a new subscriber.
    //
    // Inert for the invite/`?code=` links supabase_flutter already handles.
    await completeRecoveryLink(uri: Uri.base, auth: AuthService());
    // The local Drift DB is opened lazily by the SyncOrchestrator (via
    // appDatabaseProvider) once a session is active — see main.dart's
    // syncLifecycleProvider — and the SyncPuller fills it from Supabase on
    // sign-in. We intentionally don't eagerly open/seed it here. [runSeed] below
    // stays for tests that want a pre-populated DB without spinning up Supabase.
  }

  /// Test-visible seed entry — accepts an injected DB + seeder so tests
  /// don't have to spin up Supabase. The caller owns the [db] lifecycle.
  static Future<void> runSeed(AppDatabase db, OrdersSeeder seeder) =>
      seeder.seedIfEmpty(db);
}
