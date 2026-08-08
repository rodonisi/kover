import 'package:drift/drift.dart';
import 'package:kover/database/tables/series.dart';

class OnDeckRemoval extends Table {
  IntColumn get seriesId => integer().references(
    Series,
    #id,
    onDelete: .cascade,
  )();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  DateTimeColumn get created => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>>? get primaryKey => {seriesId};
}
