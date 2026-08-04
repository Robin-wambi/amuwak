import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'timeout_http_client.dart';

/// Boots the customer app: validates config and initialises Supabase with a
/// timeout-wrapped HTTP client. Supabase URL + anon key come from
/// `--dart-define` (see [AppConfig]). The local Drift database (cart + outbox
/// for offline resilience) is opened lazily by `customerDatabaseProvider`, so
/// there is nothing to open here.
class CustomerBootstrap {
  const CustomerBootstrap._();

  /// Returns the store `main.dart` hands to the provider scope. Primed here
  /// because [RecoveryIntentStore] is read synchronously from the router's
  /// redirect, which cannot await anything.
  static Future<RecoveryIntentStore> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = AppConfig.fromEnvironment()..validate();
    final prefs = await SharedPreferences.getInstance();
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      httpClient: TimeoutHttpClient(http.Client()),
    );
    return PersistentRecoveryIntentStore(prefs);
  }
}
