import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension CollectionDtoMappings on AppUserCollectionDto {
  /// Map available to a [CollectionsCompanion].
  CollectionsCompanion toCollectionsCompanion() {
    return CollectionsCompanion(
      id: Value(id!),
      owner: Value(owner!),
      title: Value(title!),
      summary: Value.absentIfNull(summary),
      lastSynced: Value.absentIfNull(lastSyncUtc?.normalizeUtc()),
    );
  }
}
