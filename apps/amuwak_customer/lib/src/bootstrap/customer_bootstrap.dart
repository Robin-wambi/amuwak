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

  /// What `main.dart` hands to the provider scope.
  ///
  /// Both fields are read synchronously — the router's redirect cannot await —
  /// so both are settled here, before the first frame.
  static Future<CustomerBoot> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = AppConfig.fromEnvironment()..validate();
    final prefs = await SharedPreferences.getInstance();
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      httpClient: TimeoutHttpClient(http.Client()),
    );
    // Before runApp on purpose: verifying raises `passwordRecovery`, and the
    // router seeds the recovery flag from that event. It still reaches the
    // router despite firing this early, because GoTrue's auth stream replays
    // its last event to a new subscriber.
    final link = await completeRecoveryLink(
      uri: Uri.base,
      auth: AuthService(),
    );
    return CustomerBoot(
      recoveryIntent: PersistentRecoveryIntentStore(prefs),
      recoveryLink: link,
    );
  }
}

/// The handful of things that have to be settled before the first frame.
class CustomerBoot {
  const CustomerBoot({
    required this.recoveryIntent,
    required this.recoveryLink,
  });

  final RecoveryIntentStore recoveryIntent;
  final RecoveryLinkResult recoveryLink;
}
