import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension SeriesDtoMappings on SeriesDto {
  SeriesCompanion toSeriesCompanion() {
    return SeriesCompanion(
      id: Value(id!),
      name: Value(name!),
      originalName: Value(originalName),
      localizedName: Value(localizedName),
      sortName: Value(sortName!),
      libraryId: Value(libraryId!),
      format: Value(Format.fromDtoFormat(format!)),
      pages: Value(pages!),
      wordCount: Value(wordCount ?? 0),
      minHoursToRead: Value(minHoursToRead),
      maxHoursToRead: Value(maxHoursToRead),
      avgHoursToRead: Value(avgHoursToRead),
      primaryColor: Value(primaryColor),
      secondaryColor: Value(secondaryColor),
      isBlacklisted: Value.absentIfNull(isBlacklisted),
      created: Value.absentIfNull(created?.normalizeUtc()),
      lastChapterAdded: Value.absentIfNull(lastChapterAddedUtc?.normalizeUtc()),
    );
  }
}
