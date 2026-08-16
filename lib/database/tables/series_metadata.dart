import 'package:drift/drift.dart';
import 'package:kover/database/converters/string_list_converter.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/person_role.dart';
import 'package:kover/models/enums/publication_status.dart';

@DataClassName('SeriesMetadataData')
class SeriesMetadata extends Table {
  IntColumn get id => integer()();
  IntColumn get seriesId => integer().references(
    Series,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get summary => text().nullable()();
  IntColumn get ageRating => intEnum<AgeRating>()();
  IntColumn get releaseYear => integer().nullable()();
  TextColumn get language => text().nullable()();
  IntColumn get maxCount => integer()();
  IntColumn get totalCount => integer()();
  TextColumn get publicationStatus => textEnum<PublicationStatus>()();
  TextColumn get webLinks => text().nullable()();

  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<Set<Column<Object>>>? get uniqueKeys => [
    {seriesId},
  ];
}

class People extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get primaryColor => text().nullable()();
  TextColumn get secondaryColor => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get aliases =>
      text().map(const StringListConverter()).nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Genres extends Table {
  IntColumn get id => integer()();
  TextColumn get label => text()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Tags extends Table {
  IntColumn get id => integer()();
  TextColumn get label => text()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class SeriesPeopleRoles extends Table {
  IntColumn get seriesMetadataId => integer().references(SeriesMetadata, #id)();
  IntColumn get personId => integer().references(People, #id)();
  TextColumn get role => textEnum<PersonRole>()();

  @override
  Set<Column<Object>>? get primaryKey => {seriesMetadataId, personId, role};
}

class SeriesGenres extends Table {
  IntColumn get seriesMetadataId => integer().references(SeriesMetadata, #id)();
  IntColumn get genreId => integer().references(Genres, #id)();

  @override
  Set<Column<Object>>? get primaryKey => {seriesMetadataId, genreId};
}

class SeriesTags extends Table {
  IntColumn get seriesMetadataId => integer().references(SeriesMetadata, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column<Object>>? get primaryKey => {seriesMetadataId, tagId};
}
