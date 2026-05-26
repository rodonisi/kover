import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension CollectionDtoMappings on AppUserCollectionDto {
  /// Map available to a [CollectionCompanion].
  CollectionsCompanion toCollectionsCompanion() {
    return CollectionsCompanion(
      id: Value(id!),
      title: Value(title!),
      summary: Value.absentIfNull(summary),
      lastSynced: Value.absentIfNull(lastSyncUtc?.normalizeUtc()),
    );
  }
}
