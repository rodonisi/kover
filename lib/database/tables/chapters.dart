import 'package:drift/drift.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/series_metadata.dart';
import 'package:kover/database/tables/volumes.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/person_role.dart';
import 'package:kover/models/enums/publication_status.dart';

class Chapters extends Table {
  IntColumn get id => integer()();
  IntColumn get volumeId => integer().references(Volumes, #id)();
  IntColumn get seriesId => integer().references(
    Series,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get title => text().nullable()();
  TextColumn get titleName => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get isbn => text().nullable()();
  TextColumn get format => textEnum<Format>()();
  TextColumn get language => text().nullable()();
  RealColumn get minNumber => real()();
  RealColumn get maxNumber => real()();
  RealColumn get sortOrder => real()();
  IntColumn get pages => integer()();
  IntColumn get wordCount => integer()();
  IntColumn get minHoursToRead => integer().nullable()();
  IntColumn get maxHoursToRead => integer().nullable()();
  RealColumn get avgHoursToRead => real().nullable()();
  IntColumn get ageRating => intEnum<AgeRating>()();
  TextColumn get primaryColor => text().nullable()();
  TextColumn get secondaryColor => text().nullable()();
  BoolColumn get isSpecial => boolean().withDefault(const Constant(false))();
  BoolColumn get isStoryline => boolean().withDefault(const Constant(false))();
  DateTimeColumn get releaseDate => dateTime()();
  TextColumn get publicationStatus => textEnum<PublicationStatus>()();
  DateTimeColumn get remoteLastRead => dateTime().nullable()();
  TextColumn get webLinks => text().nullable()();
  DateTimeColumn get created => dateTime()();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {id, volumeId, seriesId},
  ];
}

class ChapterCovers extends Table {
  IntColumn get chapterId => integer().references(
    Chapters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  BlobColumn get image => blob()();

  @override
  Set<Column<Object>>? get primaryKey => {chapterId};
}

class ChapterPeopleRoles extends Table {
  IntColumn get chapterId => integer().references(
    Chapters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get personId => integer().references(
    People,
    #id,
  )();
  TextColumn get role => textEnum<PersonRole>()();

  @override
  Set<Column<Object>>? get primaryKey => {chapterId, personId, role};
}

class ChapterGenres extends Table {
  IntColumn get chapterId => integer().references(
    Chapters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get genreId => integer().references(
    Genres,
    #id,
  )();

  @override
  Set<Column<Object>>? get primaryKey => {chapterId, genreId};
}

class ChapterTags extends Table {
  IntColumn get chapterId => integer().references(
    Chapters,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get tagId => integer().references(
    Tags,
    #id,
  )();

  @override
  Set<Column<Object>>? get primaryKey => {chapterId, tagId};
}
