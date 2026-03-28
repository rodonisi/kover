import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension ProgressDtoMappings on ProgressDto {
  ReadingProgressCompanion toReadingProgressCompanion() {
    return ReadingProgressCompanion(
      chapterId: Value(chapterId),
      volumeId: Value(volumeId),
      seriesId: Value(seriesId),
      libraryId: Value(libraryId),
      pagesRead: Value(pageNum),
      bookScrollId: Value(bookScrollId),
      lastModified: Value.absentIfNull(lastModifiedUtc?.normalizeUtc()),
      dirty: const Value(false),
    );
  }
}
