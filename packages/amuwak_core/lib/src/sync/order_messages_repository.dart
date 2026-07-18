import 'package:supabase_flutter/supabase_flutter.dart';

/// One per-order chat message (staff ⇄ the order's customer). Mirrors the
/// `order_messages` table (migration 0045). `senderId` is polymorphic — a
/// `staff.id` or a `customers.id` depending on [senderKind] — so it is not a FK;
/// the insert RLS policies enforce that the sender is the authenticated party.
class OrderMessage {
  const OrderMessage({
    required this.id,
    required this.orderId,
    required this.senderKind,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String orderId;

  /// `'staff'` or `'customer'`.
  final String senderKind;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isFromCustomer => senderKind == 'customer';
  bool get isFromStaff => senderKind == 'staff';
  bool get isRead => readAt != null;

  factory OrderMessage.fromSupabase(Map<String, dynamic> row) => OrderMessage(
        id: row['id'] as String,
        orderId: row['order_id'] as String,
        senderKind: row['sender_kind'] as String,
        senderId: row['sender_id'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        readAt: row['read_at'] == null
            ? null
            : DateTime.parse(row['read_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderMessage &&
          other.id == id &&
          other.orderId == orderId &&
          other.senderKind == senderKind &&
          other.senderId == senderId &&
          other.body == body &&
          other.createdAt == createdAt &&
          other.readAt == readAt;

  @override
  int get hashCode =>
      Object.hash(id, orderId, senderKind, senderId, body, createdAt, readAt);
}

/// Test seam for a row insert: given the column map, returns the "selected"
/// rows (empty ⇒ the write did not persist, e.g. an RLS policy dropped it).
typedef MessageInsert =
    Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> values);

/// Test seam for the mark-read UPDATE: given the `read_at` value and the target
/// ids, returns the affected rows.
typedef MessageMarkRead = Future<List<Map<String, dynamic>>> Function(
    DateTime readAt, List<String> ids);

/// Read + write repository for per-order chat — ONLINE-ONLY (Supabase realtime
/// `.stream()` reads; direct insert/update writes). Used by both the customer
/// app and the staff chat screen; the caller supplies [senderKind]/[senderId].
class OrderMessagesRepository {
  OrderMessagesRepository(
    SupabaseClient supabase, {
    DateTime Function()? clock,
  })  : _supabase = supabase,
        _clock = clock ?? DateTime.now,
        _insertOverride = null,
        _markReadOverride = null;

  /// Test seam: drive [send]/[markRead] (payload shape + no-write [StateError])
  /// without a live SupabaseClient. Read methods assert the client is present.
  OrderMessagesRepository.forTest({
    required DateTime Function() clock,
    MessageInsert? insertRow,
    MessageMarkRead? markReadRows,
  })  : _supabase = null,
        _clock = clock,
        _insertOverride = insertRow,
        _markReadOverride = markReadRows;

  final SupabaseClient? _supabase;
  final DateTime Function() _clock;
  final MessageInsert? _insertOverride;
  final MessageMarkRead? _markReadOverride;

  /// Live messages for one order, oldest first. Realtime via Supabase
  /// `.stream()`; RLS scopes the rows to staff or the owning customer.
  Stream<List<OrderMessage>> watchByOrder(String orderId) {
    assert(_supabase != null,
        'watchByOrder is not available on a forTest instance');
    return _supabase!
        .from('order_messages')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('created_at')
        .map((rows) =>
            rows.map(OrderMessage.fromSupabase).toList(growable: false));
  }

  /// Every message across the caller's visible orders (RLS scopes the rows:
  /// staff see all, a customer sees only their own orders' chats), newest first.
  /// Powers the customer inbox — one stream over all their order chats.
  Stream<List<OrderMessage>> watchVisible() {
    assert(_supabase != null,
        'watchVisible is not available on a forTest instance');
    return _supabase!
        .from('order_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) =>
            rows.map(OrderMessage.fromSupabase).toList(growable: false));
  }

  Future<List<Map<String, dynamic>>> _insertRow(
      Map<String, dynamic> values) async {
    final override = _insertOverride;
    if (override != null) return override(values);
    assert(_supabase != null,
        'forTest instance has no insertRow — '
        'pass one to OrderMessagesRepository.forTest(insertRow: ...)');
    return _supabase!.from('order_messages').insert(values).select('id');
  }

  /// Sends a message on [orderId], self-attributed to ([senderKind],
  /// [senderId]). `created_at` is left to the table default (server clock).
  /// Throws [StateError] if the write persisted no row (e.g. RLS dropped it) so
  /// a caller never shows "sent" for a message that didn't land.
  Future<void> send({
    required String orderId,
    required String senderKind,
    required String senderId,
    required String body,
  }) async {
    final written = await _insertRow(<String, dynamic>{
      'order_id': orderId,
      'sender_kind': senderKind,
      'sender_id': senderId,
      'body': body,
    });
    if (written.isEmpty) {
      throw StateError(
          'send: message did not persist on order "$orderId" (RLS?)');
    }
  }

  Future<List<Map<String, dynamic>>> _markReadRows(
      DateTime readAt, List<String> ids) async {
    final override = _markReadOverride;
    if (override != null) return override(readAt, ids);
    assert(_supabase != null,
        'forTest instance has no markReadRows — '
        'pass one to OrderMessagesRepository.forTest(markReadRows: ...)');
    return _supabase!
        .from('order_messages')
        .update({'read_at': readAt.toUtc().toIso8601String()})
        .inFilter('id', ids)
        .select('id');
  }

  /// Marks the given messages read (stamps `read_at`). A no-op for an empty
  /// list. Only `read_at` is written — the customer's RLS grant is column-scoped
  /// to it (migration 0046), so no other column can be touched here.
  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _markReadRows(_clock(), ids);
  }
}
