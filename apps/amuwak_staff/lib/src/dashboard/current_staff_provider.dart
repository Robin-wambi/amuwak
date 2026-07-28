import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amuwak_core/amuwak_core.dart';
import '../data/app_database.dart';
import '../sync/repository_providers.dart';

/// The signed-in staff member's profile row, streamed live, or `null` when
/// nobody is signed in / no matching row exists. Resolves to `null` rather than
/// erroring so the header can greet generically while it loads or when there's
/// no profile.
final currentStaffProvider = StreamProvider.autoDispose<StaffData?>((ref) {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(staffRepositoryProvider).watchById(id);
});
