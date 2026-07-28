import 'package:drift/drift.dart';

class ProofPhotos extends Table {
  TextColumn     get id            => text()();
  TextColumn     get proofEventId  => text().named('proof_event_id')();
  TextColumn     get storagePath   => text().named('storage_path')();
  IntColumn      get width         => integer().nullable()();
  IntColumn      get height        => integer().nullable()();
  IntColumn      get bytes         => integer().nullable()();
  DateTimeColumn get uploadedAt    => dateTime().named('uploaded_at').nullable()();
  DateTimeColumn get createdAt     => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
