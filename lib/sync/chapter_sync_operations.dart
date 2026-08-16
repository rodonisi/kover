import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/logging.dart';

class ChapterSyncOperations {
  final Openapi _client;
  final String _apiKey;

  const ChapterSyncOperations({
    required this._client,
    required this._apiKey,
  });

  /// Fetch chapter cover for [chapterId]
  Future<ChapterCoversCompanion?> getChapterCover(int chapterId) async {
    final res = await _client.apiImageChapterCoverGet(
      chapterId: chapterId,
      apiKey: _apiKey,
    );

    if (!res.isSuccessful) {
      log.debug(
        'failed to download chapter cover',
        attributes: {
          'chapter_id': chapterId,
          'status_code': res.statusCode,
        },
      );
      return null;
    }

    return ChapterCoversCompanion(
      chapterId: Value(chapterId),
      image: Value(res.bodyBytes),
    );
  }
}
