import 'package:drift/drift.dart';

class ValidTransitions extends Table {
  TextColumn get id                 => text()();
  TextColumn get intakeMethod       => text().named('intake_method')();
  TextColumn get fulfillmentMethod  => text().named('fulfillment_method')();
  TextColumn get fromStatus         => text().named('from_status').nullable()();
  TextColumn get toStatus           => text().named('to_status')();

  @override
  Set<Column> get primaryKey => {id};
}
