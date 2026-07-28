import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/repository_providers.dart';

/// The private bucket customers upload damage photos to (Supabase migration
/// `0052`). Staff of any active role may read the whole bucket.
const kCustomerUploadsBucket = 'customer-uploads';

/// How long a generated link stays valid. Short: it only has to outlive the
/// staff member looking at the order, and a leaked link expires quickly.
const kCustomerPhotoUrlTtl = Duration(minutes: 10);

/// Turns a `customer-uploads` object key into a URL the app can display, or null
/// when it can't be resolved (offline, or the customer's upload hasn't drained
/// from their outbox yet). Injectable so screens can be tested — and driven
/// offline — without Storage.
typedef CustomerPhotoUrlResolver = Future<String?> Function(String objectKey);

/// Signs a URL for one customer photo. The bucket is private, so an unsigned
/// public URL would 400; a failure (no network, object not uploaded yet) returns
/// null rather than throwing, because a missing damage photo must never break
/// the order screen a rider is trying to work from.
CustomerPhotoUrlResolver supabaseCustomerPhotoUrl(SupabaseClient supabase) =>
    (objectKey) async {
      try {
        return await supabase.storage
            .from(kCustomerUploadsBucket)
            .createSignedUrl(objectKey, kCustomerPhotoUrlTtl.inSeconds);
      } catch (_) {
        return null;
      }
    };

final customerPhotoUrlResolverProvider = Provider<CustomerPhotoUrlResolver>(
  (ref) => supabaseCustomerPhotoUrl(ref.watch(supabaseClientProvider)),
);
