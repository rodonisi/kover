import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/server_settings_dto_mappings.dart';

class ServerSettingsSyncOperations {
  final Openapi _client;

  const ServerSettingsSyncOperations({
    required this._client,
  });

  /// Fetch server settings
  Future<ServerSettingsCompanion> getServerSettings() async {
    final res = await _client.apiSettingsGet();

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load chapter: ${res.error}');
    }

    return res.body!.toServerSettingsCompanion();
  }
}
