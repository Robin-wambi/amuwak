import 'dart:convert';
import 'dart:typed_data';

import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_customer/src/cart/cart_photo.dart';
import 'package:amuwak_customer/src/cart/cart_repository.dart';
import 'package:amuwak_customer/src/data/customer_database.dart';
import 'package:amuwak_customer/src/sync/outbox_worker.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late CustomerDatabase db;
  late CartRepository cart;
  late OutboxWorker outbox;
  late CartPhotoService photos;
  var seq = 0;

  final bytes = Uint8List.fromList([1, 2, 3, 4]);
  final other = Uint8List.fromList([9, 9]);
  final now = DateTime.utc(2026, 7, 27, 9);

  setUp(() {
    db = CustomerDatabase.forTesting(NativeDatabase.memory());
    seq = 0;
    String nextId() => 'id${seq++}';
    cart = CartRepository(db, newId: nextId);
    outbox = OutboxWorker(db, clock: () => now);
    photos = CartPhotoService(
      db: db,
      outbox: outbox,
      clock: () => now,
      newId: nextId,
    );
  });
  // `attach` kicks a drain without awaiting it (so the UI stays snappy) — let
  // that settle before closing, or it reopens a closed database.
  tearDown(() async {
    await pumpEventQueue();
    await db.close();
  });

  Future<CartItem> addLine() async {
    await cart.addWeightItem(service: ServiceType.washAndIron, estKg: 6);
    return (await db.cartItemsOnce()).last;
  }

  test('a photo key is scoped to the owning customer', () {
    expect(
      buildCartPhotoKey(customerId: 'cust-1', photoId: 'p9'),
      'customer/cust-1/cart/p9.jpg',
    );
  });

  group('attach', () {
    test('stores bytes locally, points the line at the key, queues the upload',
        () async {
      final item = await addLine();
      final key = await photos.attach(
          item: item, bytes: bytes, customerId: 'cust-1');

      expect(key, startsWith('customer/cust-1/cart/'));
      expect((await db.localPhoto(key))!.bytes, bytes);
      expect((await db.cartItemsOnce()).single.photoKey, key);

      final queued = await db.dueOutbox(now);
      expect(queued.single.opType, kPhotoUploadOp);
      expect(jsonDecode(queued.single.payload), {'key': key});
    });

    test('replacing a photo drops the bytes of the one it replaces', () async {
      final item = await addLine();
      final first = await photos.attach(
          item: item, bytes: bytes, customerId: 'cust-1');
      final reloaded = (await db.cartItemsOnce()).single;
      final second = await photos.attach(
          item: reloaded, bytes: other, customerId: 'cust-1');

      expect(second, isNot(first));
      expect(await db.localPhoto(first), isNull);
      expect((await db.localPhoto(second))!.bytes, other);
      expect((await db.cartItemsOnce()).single.photoKey, second);
    });
  });

  test('detach clears the line and its bytes', () async {
    final item = await addLine();
    final key =
        await photos.attach(item: item, bytes: bytes, customerId: 'cust-1');

    await photos.detach((await db.cartItemsOnce()).single);

    expect((await db.cartItemsOnce()).single.photoKey, isNull);
    expect(await db.localPhoto(key), isNull);
  });

  test('removing the cart line drops its photo bytes', () async {
    final item = await addLine();
    final key =
        await photos.attach(item: item, bytes: bytes, customerId: 'cust-1');

    await cart.remove(item.id);

    expect(await db.cartItemsOnce(), isEmpty);
    expect(await db.localPhoto(key), isNull);
  });

  group('upload handler', () {
    test('uploads the queued bytes and keeps them while the line previews them',
        () async {
      final item = await addLine();
      final key =
          await photos.attach(item: item, bytes: bytes, customerId: 'cust-1');
      final uploaded = <String, Uint8List>{};

      await uploadCartPhotoFromPayload(
        db,
        (k, b) async => uploaded[k] = b,
        jsonEncode({'key': key}),
      );

      expect(uploaded, {key: bytes});
      final photo = await db.localPhoto(key);
      expect(photo, isNotNull, reason: 'still shown on the cart line');
      expect(photo!.uploaded, isTrue);
    });

    test('drops the bytes once no cart line previews them', () async {
      final item = await addLine();
      final key =
          await photos.attach(item: item, bytes: bytes, customerId: 'cust-1');
      await db.clearCart(); // checkout

      await uploadCartPhotoFromPayload(
          db, (k, b) async {}, jsonEncode({'key': key}));

      expect(await db.localPhoto(key), isNull);
    });

    test('a photo removed before it went up is a no-op success', () async {
      var called = false;
      await uploadCartPhotoFromPayload(
        db,
        (k, b) async => called = true,
        jsonEncode({'key': 'customer/cust-1/cart/gone.jpg'}),
      );
      expect(called, isFalse);
    });

    test('a failed upload re-queues instead of losing the photo', () async {
      outbox.register(
        kPhotoUploadOp,
        (p) => uploadCartPhotoFromPayload(
            db, (k, b) async => throw Exception('offline'), p),
      );
      final item = await addLine();

      // Attaching kicks the outbox itself, so the attempt happens right here.
      final key =
          await photos.attach(item: item, bytes: bytes, customerId: 'cust-1');
      await pumpEventQueue();

      final queued = await db.select(db.outbox).get();
      expect(queued.single.attempts, 1);
      expect(queued.single.nextAttemptAt, isNotNull);
      expect((await db.localPhoto(key))!.uploaded, isFalse,
          reason: 'bytes survive for the retry');
    });

    test('attaching while online uploads straight away', () async {
      final uploaded = <String>[];
      outbox.register(
        kPhotoUploadOp,
        (p) => uploadCartPhotoFromPayload(
            db, (k, b) async => uploaded.add(k), p),
      );
      final item = await addLine();

      final key =
          await photos.attach(item: item, bytes: bytes, customerId: 'cust-1');
      await pumpEventQueue();

      expect(uploaded, [key]);
      expect(await db.dueOutbox(now), isEmpty);
      expect((await db.localPhoto(key))!.uploaded, isTrue);
    });
  });

  test('checkout keeps a not-yet-uploaded photo, sweep drops an uploaded one',
      () async {
    final pending = await addLine();
    final pendingKey = await photos.attach(
        item: pending, bytes: bytes, customerId: 'cust-1');
    await cart.addWeightItem(service: ServiceType.washOnly, estKg: 2);
    final done = (await db.cartItemsOnce()).last;
    final doneKey =
        await photos.attach(item: done, bytes: other, customerId: 'cust-1');
    await uploadCartPhotoFromPayload(
        db, (k, b) async {}, jsonEncode({'key': doneKey}));

    // Checkout: the cart empties but the queued upload must still find bytes.
    await db.clearCart();
    await db.sweepLocalPhotos();

    expect(await db.localPhoto(pendingKey), isNotNull);
    expect(await db.localPhoto(doneKey), isNull);
  });

  group('duplicate objects', () {
    test('a re-upload of the same key counts as already done', () {
      expect(
        isDuplicateObject(
            const StorageException('exists', statusCode: '409')),
        isTrue,
      );
      expect(
        isDuplicateObject(
            const StorageException('exists', error: 'Duplicate')),
        isTrue,
      );
    });

    test('a real failure is still a failure', () {
      expect(
        isDuplicateObject(
            const StorageException('denied', statusCode: '403')),
        isFalse,
      );
    });
  });

  test('the photo key rides into the staff-facing cart snapshot', () async {
    final item = await addLine();
    final key =
        await photos.attach(item: item, bytes: bytes, customerId: 'cust-1');

    final snap = cartItemsSnapshot(await db.cartItemsOnce());

    expect(snap.single['photo_key'], key);
  });
}
