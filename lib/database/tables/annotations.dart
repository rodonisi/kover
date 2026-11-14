import 'package:drift/drift.dart';
import 'package:kover/database/converters/int_list_converter.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/libraries.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/volumes.dart';
import 'package:kover/models/enums/age_rating.dart';

class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get seriesId =>
      integer().references(Series, #id, onDelete: .cascade)();
  IntColumn get volumeId => integer().references(Volumes, #id)();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: .cascade)();
  IntColumn get libraryId =>
      integer().references(Libraries, #id, onDelete: .cascade)();
  IntColumn get ownerUserId => integer()();
  TextColumn get ownerUsername => text().nullable()();
  TextColumn get xPath => text().nullable()();
  TextColumn get endingXPath => text().nullable()();
  TextColumn get selectedText => text().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get commentHtml => text().nullable()();
  TextColumn get commentPlainText => text().nullable()();
  TextColumn get chapterTitle => text().nullable()();
  TextColumn get context => text().nullable()();
  IntColumn get highlightCount => integer().nullable()();
  BoolColumn get containsSpoiler => boolean().nullable()();
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get selectedSlotIndex => integer().nullable()();
  TextColumn get likes =>
      text().map(const IntListConverter()).withDefault(const Constant('[]'))();
  TextColumn get seriesName => text().nullable()();
  TextColumn get libraryName => text().nullable()();
  IntColumn get ageRating => intEnum<AgeRating>().nullable()();
  DateTimeColumn get created => dateTime().nullable()();
  DateTimeColumn get lastModified => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {serverId},
  ];
}
