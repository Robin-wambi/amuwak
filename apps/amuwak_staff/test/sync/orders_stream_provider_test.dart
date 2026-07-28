@Skip('Online-only mode: this test wrote through ordersRepositoryProvider and '
    'expected the row to surface from the local Drift DB via ordersStreamProvider. '
    'Online, the repo reads/writes Supabase, so this offline round-trip no longer '
    'applies. Original preserved in git history. The online ordersStreamProvider '
    'wiring is exercised in test/dashboard/staff_dashboard_screen_test.dart '
    '(overridden stream) and the mapping in test/sync/supabase_mappers_test.dart.')
library;

import 'package:flutter_test/flutter_test.dart';

void main() {}
