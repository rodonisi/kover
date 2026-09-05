import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';

extension GroupedSeriesDtoMappings on GroupedSeriesDto {
  SeriesCompanion toSeriesCompanion() {
    return SeriesCompanion(
      id: Value(seriesId!),
      libraryId: Value(libraryId!),
      name: Value.absentIfNull(seriesName),
      isRecentlyUpdated: const Value(true),
    );
  }
}
