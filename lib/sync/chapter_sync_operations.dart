import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/logging.dart';

class const ChapterSyncOperations({required final Openapi _client}) {
  /// Fetch chapter cover for [chapterId]
  Future<ChapterCoversCompanion?> getChapterCover(int chapterId) async {
    final res = await _client.apiImageChapterCoverGet(chapterId: chapterId);

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
