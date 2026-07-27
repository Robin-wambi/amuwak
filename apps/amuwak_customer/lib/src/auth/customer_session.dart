import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The live Supabase client (initialised in [CustomerBootstrap]). A provider so
/// tests can override it with a fake.
final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final customerProfileRepositoryProvider = Provider<CustomerProfileRepository>(
  (ref) => CustomerProfileRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in customer's own profile row, or null when signed out / not yet
/// resolved. Only subscribes once the JWT carries the `customer` role (set by
/// the access-token hook after signup + link), so a staff user or a signed-out
/// visitor never opens the stream.
final currentCustomerProvider = StreamProvider<Customer?>((ref) {
  final role = ref.watch(currentRoleProvider);
  if (role != 'customer') return Stream<Customer?>.value(null);
  return ref.watch(customerProfileRepositoryProvider).watchMe();
});

/// The signed-in customer's `customers.id`, or null until [currentCustomerProvider]
/// resolves. The id every customer-scoped repository call needs.
final currentCustomerIdProvider = Provider<String?>(
  (ref) => ref.watch(currentCustomerProvider).valueOrNull?.id,
);
