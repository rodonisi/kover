import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/logging.dart';

class const VolumeSyncOperations({required final Openapi _client}) {
  /// Get cover for volume [volumeId]
  Future<VolumeCoversCompanion?> getVolumeCover(int volumeId) async {
    final res = await _client.apiImageVolumeCoverGet(
      volumeId: volumeId,
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
