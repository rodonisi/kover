import 'package:drift/drift.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/libraries.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/volumes.dart';

@DataClassName('ReadingProgressData')
class ReadingProgress extends Table {
  IntColumn get chapterId => integer().references(
    Chapters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get volumeId => integer().references(Volumes, #id)();
  IntColumn get seriesId => integer().references(Series, #id)();
  IntColumn get libraryId => integer().references(Libraries, #id)();
  IntColumn get pagesRead => integer().withDefault(const Constant(0))();
  TextColumn get bookScrollId => text().nullable()();
  IntColumn get totalReads => integer().withDefault(const Constant(0))();

  DateTimeColumn get created => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastModified =>
      dateTime().withDefault(currentDateAndTime)();

  /// Whether the entry has been modified locally
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>>? get primaryKey => {chapterId};
}
