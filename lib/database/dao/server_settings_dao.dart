import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/server_settings.dart';
import 'package:kover/utils/data_constants.dart';

part 'server_settings_dao.g.dart';

@DriftAccessor(tables: [ServerSettings])
class ServerSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$ServerSettingsDaoMixin {
  ServerSettingsDao(super.attachedDatabase);

  /// Watch the server version, which is stored in the database.
  Stream<String?> watchServerVersion() {
    return managers.serverSettings
        .filter((f) => f.key(DataConstants.serverSettingsKey))
        .map((e) => e.installVersion)
        .watchSingle();
  }

  /// Insert or update the server settings in the database.
  Future<void> upsertServerSettings(
    ServerSettingsCompanion companion,
  ) async {
    await into(serverSettings).insertOnConflictUpdate(companion);
  }
}
