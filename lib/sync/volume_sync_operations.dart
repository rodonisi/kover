import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/logging.dart';

class VolumeSyncOperations {
  final Openapi _client;
  final String _apiKey;

  const VolumeSyncOperations({
    required this._client,
    required this._apiKey,
  });

  /// Get cover for volume [volumeId]
  Future<VolumeCoversCompanion?> getVolumeCover(int volumeId) async {
    final res = await _client.apiImageVolumeCoverGet(
      volumeId: volumeId,
      apiKey: _apiKey,
    );

    if (!res.isSuccessful) {
      log.debug(
        'failed to download volume cover',
        attributes: {
          'volume_id': volumeId,
          'status_code': res.statusCode,
        },
      );
      return null;
    }

    return VolumeCoversCompanion(
      volumeId: Value(volumeId),
      image: Value(res.bodyBytes),
    );
  }
}
