import 'dart:developer' as developer;

enum ProofEventType {
  pickup,
  delivery;

  /// Maps a Postgres `proof_events.type` string to the UI enum.
  ///
  /// Same stream-safety rationale as `OrderStatus.fromDbString`: an unknown
  /// type synced from a newer backend degrades to [pickup] + a log rather than
  /// throwing, so it can never crash the orders stream.
  static ProofEventType fromDbString(String s) => switch (s) {
        'pickup' => ProofEventType.pickup,
        'delivery' => ProofEventType.delivery,
        _ => _degradeUnknown(s),
      };

  static ProofEventType _degradeUnknown(String s) {
    developer.log(
      'Unknown proof event type "$s" — defaulting to pickup.',
      name: 'ProofEventType',
    );
    return ProofEventType.pickup;
  }
}

class ProofEvent {
  const ProofEvent({
    required this.id,
    required this.type,
    required this.capturedAt,
    required this.count,
    required this.photoPaths,
    this.notes,
  });

  final String id;
  final ProofEventType type;
  final DateTime capturedAt;
  final int count;
  final List<String> photoPaths;
  final String? notes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProofEvent) return false;
    if (id != other.id) return false;
    if (type != other.type) return false;
    if (capturedAt != other.capturedAt) return false;
    if (count != other.count) return false;
    if (notes != other.notes) return false;
    if (photoPaths.length != other.photoPaths.length) return false;
    for (var i = 0; i < photoPaths.length; i++) {
      if (photoPaths[i] != other.photoPaths[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        capturedAt,
        count,
        notes,
        Object.hashAll(photoPaths),
      );
}
