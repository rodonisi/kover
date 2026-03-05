import 'package:drift/drift.dart';
import 'package:fluvita/database/tables/series.dart';

class Volumes extends Table {
  IntColumn get id => integer()();
  IntColumn get seriesId => integer().references(
    Series,
    #id,
    onDelete: KeyAction.cascade,
  )();
  RealColumn get minNumber => real()();
  RealColumn get maxNumber => real()();
  TextColumn get name => text().nullable()();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  IntColumn get pages => integer()();
  IntColumn get minHoursToRead => integer().nullable()();
  IntColumn get maxHoursToRead => integer().nullable()();
  RealColumn get avgHoursToRead => real().nullable()();
  TextColumn get primaryColor => text().nullable()();
  TextColumn get secondaryColor => text().nullable()();

  DateTimeColumn get created => dateTime()();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {id, seriesId},
  ];
}

class VolumeCovers extends Table {
  IntColumn get volumeId => integer().references(
    Volumes,
    #id,
    onDelete: KeyAction.cascade,
  )();
  BlobColumn get image => blob()();

  @override
  Set<Column<Object>>? get primaryKey => {volumeId};
}
