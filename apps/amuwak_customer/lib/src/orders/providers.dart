import 'package:amuwak_core/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/customer_session.dart';

final customerOrdersRepositoryProvider = Provider<CustomerOrdersRepository>(
  (ref) => CustomerOrdersRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in customer's own orders, live. Emits an empty list until the
/// customer id resolves (so the UI shows "no orders yet" rather than a spinner
/// forever on a not-yet-linked session). Auto-disposes when no screen watches.
final myOrdersProvider = StreamProvider.autoDispose<List<LaundryOrder>>((ref) {
  final customerId = ref.watch(currentCustomerIdProvider);
  if (customerId == null) return Stream.value(const <LaundryOrder>[]);
  return ref.watch(customerOrdersRepositoryProvider).watchMine(customerId);
});
