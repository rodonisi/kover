import 'package:drift/drift.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/volumes.dart';

@DataClassName('BookmarkData')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get seriesId =>
      integer().references(Series, #id, onDelete: .cascade)();
  IntColumn get volumeId => integer().references(Volumes, #id)();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: .cascade)();
  IntColumn get page => integer()();
  IntColumn get imageOffset => integer().withDefault(const Constant(0))();
  TextColumn get xPath => text().nullable()();
  DateTimeColumn get created => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {chapterId, page, xPath, imageOffset},
  ];
}
