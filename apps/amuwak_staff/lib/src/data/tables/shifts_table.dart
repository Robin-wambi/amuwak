import 'package:drift/drift.dart';

class Shifts extends Table {
  TextColumn     get id          => text()();
  TextColumn     get staffId     => text().named('staff_id')();
  DateTimeColumn get startedAt   => dateTime().named('started_at')();
  RealColumn     get startedLat  => real().named('started_lat').nullable()();
  RealColumn     get startedLng  => real().named('started_lng').nullable()();
  DateTimeColumn get endedAt     => dateTime().named('ended_at').nullable()();
  RealColumn     get endedLat    => real().named('ended_lat').nullable()();
  RealColumn     get endedLng    => real().named('ended_lng').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
