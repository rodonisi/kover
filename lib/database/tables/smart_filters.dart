import 'package:drift/drift.dart';
import 'package:kover/database/tables/reading_lists.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/series_metadata.dart';
import 'package:kover/models/enums/filter_type.dart';

class SmartFilters extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().nullable()();
  TextColumn get filter => text().nullable()();
  IntColumn get type => intEnum<FilterType>()();

  DateTimeColumn get lastModified =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get created => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class SmartFilterSeries extends Table {
  IntColumn get smartFilterId => integer().references(
    SmartFilters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get seriesId => integer().references(
    Series,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  Set<Column<Object>>? get primaryKey => {smartFilterId, seriesId};
}

class SmartFilterReadingList extends Table {
  IntColumn get smartFilterId => integer().references(
    SmartFilters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get readingListId => integer().references(
    ReadingLists,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  Set<Column<Object>>? get primaryKey => {smartFilterId, readingListId};
}

class SmartFilterPerson extends Table {
  IntColumn get smartFilterId => integer().references(
    SmartFilters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get personId => integer().references(
    People,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  Set<Column<Object>>? get primaryKey => {smartFilterId, personId};
}
