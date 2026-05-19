import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/server_settings.dart';

part 'server_settings_dao.g.dart';

@DriftAccessor(tables: [ServerSettings])
class ServerSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$ServerSettingsDaoMixin {
  ServerSettingsDao(super.attachedDatabase);

  Future<void> upsertServerSettings(
    ServerSettingsCompanion companion,
  ) async {
    await into(serverSettings).insertOnConflictUpdate(companion);
  }
}
