import 'package:drift/drift.dart';

class Staff extends Table {
  TextColumn get id            => text()();
  TextColumn get username      => text()();
  TextColumn get displayName   => text().named('display_name')();
  TextColumn get phone         => text().nullable()();
  TextColumn get role          => text()();
  BoolColumn get active        => boolean().withDefault(const Constant(true))();
  BoolColumn get mustChangePin => boolean().named('must_change_pin').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
