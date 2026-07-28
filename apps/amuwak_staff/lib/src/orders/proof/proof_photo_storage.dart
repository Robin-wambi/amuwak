import '../proof_event.dart';

typedef PickPhotoFn = Future<List<int>?> Function();

abstract class ProofPhotoStorage {
  Future<String> save({
    required String orderId,
    required ProofEventType type,
    required int index,
    required List<int> bytes,
  });
}

class SavedProofPhoto {
  const SavedProofPhoto({required this.path, required this.bytes});

  final String path;
  final List<int> bytes;
}

class InMemoryProofPhotoStorage implements ProofPhotoStorage {
  InMemoryProofPhotoStorage();

  final List<SavedProofPhoto> savedPhotos = [];

  @override
  Future<String> save({
    required String orderId,
    required ProofEventType type,
    required int index,
    required List<int> bytes,
  }) async {
    final path = 'memory://$orderId/${type.name}_$index';
    savedPhotos.add(SavedProofPhoto(path: path, bytes: bytes));
    return path;
  }
}
