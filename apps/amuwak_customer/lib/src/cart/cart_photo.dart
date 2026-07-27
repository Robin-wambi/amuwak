import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/customer_session.dart';
import '../data/customer_database.dart';
import '../sync/outbox_worker.dart';
import '../sync/sync_providers.dart';

/// The op-type of a queued damage-photo upload in the outbox.
const kPhotoUploadOp = 'photo_upload';

/// Private bucket for customer-supplied photos (migration `0052`). RLS scopes a
/// customer to their own `customer/<auth_customer_id>/` prefix; staff read all.
const kCustomerUploadsBucket = 'customer-uploads';

/// The object key a cart-line photo is stored under. The `customer/<id>/` prefix
/// is what the bucket's RLS policies match on, so it must be the owning
/// customer's `customers.id` — not their auth user id.
String buildCartPhotoKey({
  required String customerId,
  required String photoId,
}) =>
    'customer/$customerId/cart/$photoId.jpg';

/// Puts one photo in Storage. An abstraction so the outbox handler is testable
/// without a Supabase client.
typedef PhotoUploader = Future<void> Function(String key, Uint8List bytes);

/// Attaches damage photos to cart lines, offline-safe: the compressed bytes are
/// written to the local DB and the upload is queued in the outbox, while the
/// object key goes onto the cart line immediately so it rides into the order's
/// `cart_items` snapshot at checkout even if the upload has not drained yet.
class CartPhotoService {
  CartPhotoService({
    required CustomerDatabase db,
    required OutboxWorker outbox,
    DateTime Function()? clock,
    String Function()? newId,
  })  : _db = db,
        _outbox = outbox,
        _clock = clock ?? DateTime.now,
        _newId = newId ?? defaultUuidV7;

  final CustomerDatabase _db;
  final OutboxWorker _outbox;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Stores already-compressed [bytes] for [item] and queues the upload,
  /// returning the Storage key the line now carries. Replacing a photo discards
  /// the previous local bytes (an object already uploaded stays in the bucket,
  /// unreferenced).
  Future<String> attach({
    required CartItem item,
    required Uint8List bytes,
    required String customerId,
  }) async {
    final key = buildCartPhotoKey(customerId: customerId, photoId: _newId());
    final now = _clock();
    await _db.putLocalPhoto(key: key, bytes: bytes, now: now);
    await _db.upsertCartItem(
        item.toCompanion(true).copyWith(photoKey: Value(key)));
    final previous = item.photoKey;
    if (previous != null) await _db.deleteLocalPhoto(previous);
    await _db.enqueue(
      id: _newId(),
      opType: kPhotoUploadOp,
      payload: jsonEncode({'key': key}),
      now: now,
    );
    unawaited(_outbox.drain());
    return key;
  }

  /// Takes the photo off [item] and deletes its local bytes; a still-queued
  /// upload for it becomes a no-op, so removing a photo also cancels it.
  Future<void> detach(CartItem item) async {
    final key = item.photoKey;
    await _db.upsertCartItem(
        item.toCompanion(true).copyWith(photoKey: const Value(null)));
    if (key != null) await _db.deleteLocalPhoto(key);
  }

  /// The local bytes behind a cart line's photo, or null once they have been
  /// uploaded and swept.
  Future<Uint8List?> bytes(String key) async =>
      (await _db.localPhoto(key))?.bytes;
}

/// The outbox handler for [kPhotoUploadOp]. Bytes missing from the local DB mean
/// the customer removed the photo before it went up — that counts as done.
/// After a successful upload the bytes are kept while a cart line still previews
/// them (they are swept once the cart is checked out).
Future<void> uploadCartPhotoFromPayload(
  CustomerDatabase db,
  PhotoUploader upload,
  String payloadJson,
) async {
  final key = (jsonDecode(payloadJson) as Map)['key'] as String;
  final photo = await db.localPhoto(key);
  if (photo == null) return;
  await upload(key, photo.bytes);
  await db.markPhotoUploaded(key);
  if (!await db.isPhotoReferenced(key)) await db.deleteLocalPhoto(key);
}

/// Whether a Storage error means the object is already up there — an earlier
/// attempt succeeded but its response never reached us. Keys carry a UUID, so a
/// collision can only be our own retry.
bool isDuplicateObject(StorageException e) =>
    e.statusCode == '409' || e.error == 'Duplicate';

/// Uploads into the private [kCustomerUploadsBucket]. NOT an upsert: the bucket
/// has no UPDATE policy (migration `0052` keeps customer uploads immutable), so
/// a retry is settled by [isDuplicateObject] instead — otherwise it would 403
/// forever and wedge the queue.
PhotoUploader supabasePhotoUploader(SupabaseClient supabase) =>
    (key, bytes) async {
      try {
        await supabase.storage.from(kCustomerUploadsBucket).uploadBinary(
              key,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
      } on StorageException catch (e) {
        if (isDuplicateObject(e)) return;
        rethrow;
      }
    };

final cartPhotoServiceProvider = Provider<CartPhotoService>(
  (ref) => CartPhotoService(
    db: ref.watch(customerDatabaseProvider),
    outbox: ref.watch(outboxWorkerProvider),
  ),
);

/// The local bytes of a cart line's photo, for the preview thumbnail.
final cartPhotoBytesProvider = FutureProvider.family<Uint8List?, String>(
  (ref, key) => ref.watch(cartPhotoServiceProvider).bytes(key),
);

/// Registers the [kPhotoUploadOp] handler on the outbox worker. Watched from the
/// app shell (like `placeOrderHandlerProvider`) so a photo queued in a previous
/// session uploads on launch.
final photoUploadHandlerProvider = Provider<void>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final db = ref.watch(customerDatabaseProvider);
  final upload = supabasePhotoUploader(supabase);
  ref.watch(outboxWorkerProvider).register(
        kPhotoUploadOp,
        (payload) => uploadCartPhotoFromPayload(db, upload, payload),
      );
});
