import 'package:drift/drift.dart';
import 'package:kover/database/tables/chapters.dart';

class ReadingLists extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get summary => text().nullable()();
  TextColumn get primaryColor => text().nullable()();
  TextColumn get secondaryColor => text().nullable()();
  TextColumn get owner => text()();
  DateTimeColumn get lastSyncCheck => dateTime().nullable()();
  DateTimeColumn get lastSynced => dateTime().nullable()();

  DateTimeColumn get created => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastModified =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ReadingListsChapters extends Table {
  IntColumn get readingListId => integer().references(
    ReadingLists,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get chapterId => integer().references(
    Chapters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get order => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {readingListId, chapterId};
}

class ReadingListCovers extends Table {
  IntColumn get readingListId => integer().references(
    ReadingLists,
    #id,
    onDelete: KeyAction.cascade,
  )();
  BlobColumn get image => blob()();

  @override
  Set<Column<Object>>? get primaryKey => {readingListId};
}
