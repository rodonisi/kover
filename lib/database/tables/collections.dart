import 'package:drift/drift.dart';
import 'package:kover/database/tables/series.dart';

class Collections extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get summary => text().nullable()();
  TextColumn get primaryColor => text().nullable()();
  TextColumn get secondaryColor => text().nullable()();
  TextColumn get owner => text()();
  DateTimeColumn get lastSynced => dateTime()();
  DateTimeColumn get created => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastModified =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class CollectionSeries extends Table {
  IntColumn get collectionId => integer().references(
    Collections,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get seriesId => integer().references(
    Series,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  Set<Column<Object>>? get primaryKey => {collectionId, seriesId};
}

class CollectionCovers extends Table {
  IntColumn get collectionId => integer().references(
    Collections,
    #id,
    onDelete: KeyAction.cascade,
  )();
  BlobColumn get image => blob()();

  @override
  Set<Column<Object>>? get primaryKey => {collectionId};
}
