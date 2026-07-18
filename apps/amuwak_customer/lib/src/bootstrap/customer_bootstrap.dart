import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'timeout_http_client.dart';

/// Boots the customer app: validates config and initialises Supabase with a
/// timeout-wrapped HTTP client. Deliberately Drift-free — the customer app is
/// online-only, so unlike the staff app there is no local database to open.
/// Supabase URL + anon key come from `--dart-define` (see [AppConfig]).
class CustomerBootstrap {
  const CustomerBootstrap._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = AppConfig.fromEnvironment()..validate();
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      httpClient: TimeoutHttpClient(http.Client()),
    );
  }
}
