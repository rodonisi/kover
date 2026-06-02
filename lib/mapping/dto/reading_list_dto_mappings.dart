import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension ReadingListDtoMappings on ReadingListDto {
  ReadingListsCompanion toReadingListCompanion() {
    return ReadingListsCompanion.insert(
      id: Value(id!),
      title: title!,
      summary: Value.absentIfNull(summary),
      owner: ownerUserName!,
      primaryColor: Value.absentIfNull(primaryColor),
      secondaryColor: Value.absentIfNull(secondaryColor),
      lastSyncCheck: Value.absentIfNull(lastSyncCheckUtc?.normalizeUtc()),
      lastSynced: Value.absentIfNull(lastSyncedUtc?.normalizeUtc()),
      lastModified: Value(DateTime.timestamp()),
    );
  }
}
