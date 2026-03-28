import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/dao/volumes_dao.dart';
import 'package:kover/mapping/dto/chapter_dto_mappings.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension VolumeDtoMappings on VolumeDto {
  VolumeWithChaptersCompanion toVolumeCompanion() {
    return VolumeWithChaptersCompanion(
      volume: VolumesCompanion(
        id: Value(id!),
        seriesId: Value(seriesId!),
        minNumber: Value(minNumber!),
        maxNumber: Value(maxNumber!),
        name: Value.absentIfNull(name),
        wordCount: Value(wordCount!),
        pages: Value(pages!),
        minHoursToRead: Value.absentIfNull(minHoursToRead),
        maxHoursToRead: Value.absentIfNull(maxHoursToRead),
        avgHoursToRead: Value.absentIfNull(avgHoursToRead),
        primaryColor: Value.absentIfNull(primaryColor),
        secondaryColor: Value.absentIfNull(secondaryColor),
        created: Value.absentIfNull(createdUtc?.normalizeUtc()),
        lastModified: Value.absentIfNull(lastModifiedUtc?.normalizeUtc()),
      ),
      chapters: (chapters ?? []).map(
        (c) => c.toChapterCompanion().copyWith(
          seriesId: Value(seriesId!),
        ),
      ),
    );
  }
}
