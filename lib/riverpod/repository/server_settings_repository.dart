import 'package:kover/database/app_database.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/server_settings_sync_operations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'server_settings_repository.g.dart';

@Riverpod(keepAlive: true)
ServerSettingsRepository serverSettingsRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final client = ServerSettingsSyncOperations(
    client: restClient,
  );

  return ServerSettingsRepository(db: db, client: client);
}

class ServerSettingsRepository {
  final AppDatabase _db;
  final ServerSettingsSyncOperations _client;

  ServerSettingsRepository({
    required this._db,
    required this._client,
  });

  Stream<String?> watchServerVersion() {
    return _db.serverSettingsDao.watchServerVersion();
  }

  /// Fetch server settings from the server and store them in the database
  Future<void> refreshServerSettings() async {
    final settingsCompanion = await _client.getServerSettings();
    await _db.serverSettingsDao.upsertServerSettings(settingsCompanion);
  }
}
