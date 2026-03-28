import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension ChapterDtoMappings on ChapterDto {
  /// Map available to a [ReadingProgressCompanion].
  /// seriesId, libraryId, scrollId will missing from the companion.
  ReadingProgressCompanion toPartialReadingProgressCompanion() {
    return ReadingProgressCompanion(
      chapterId: Value(id!),
      volumeId: Value(volumeId!),
      pagesRead: Value(pagesRead!),
      totalReads: Value(totalReads!),
      lastModified: Value.absentIfNull(lastReadingProgressUtc?.normalizeUtc()),
    );
  }

  ChaptersCompanion toChapterCompanion() {
    return ChaptersCompanion(
      id: Value(id!),
      volumeId: Value(volumeId!),
      title: Value(title),
      titleName: Value(titleName),
      description: Value(summary),
      summary: Value(summary),
      isbn: Value(isbn),
      format: Value(
        format != null ? Format.fromDtoFormat(format!) : .unknown,
      ),
      language: Value.absentIfNull(language),
      minNumber: Value(minNumber!),
      maxNumber: Value(maxNumber!),
      sortOrder: Value.absentIfNull(sortOrder),
      pages: Value(pages!),
      wordCount: Value.absentIfNull(wordCount),
      minHoursToRead: Value.absentIfNull(minHoursToRead),
      maxHoursToRead: Value.absentIfNull(maxHoursToRead),
      avgHoursToRead: Value.absentIfNull(avgHoursToRead),
      ageRating: Value.absentIfNull(ageRating),
      primaryColor: Value.absentIfNull(primaryColor),
      secondaryColor: Value.absentIfNull(secondaryColor),
      isSpecial: Value.absentIfNull(isSpecial),
      releaseDate: Value.absentIfNull(releaseDate?.normalizeUtc()),
      created: Value.absentIfNull(createdUtc?.normalizeUtc()),
      lastModified: Value.absentIfNull(lastModifiedUtc?.normalizeUtc()),
    );
  }
}
