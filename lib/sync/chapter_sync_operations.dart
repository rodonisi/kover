import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/chapter_dto_mappings.dart';
import 'package:kover/utils/logging.dart';

class ChapterSyncOperations {
  final Openapi _client;
  final String _apiKey;

  const ChapterSyncOperations({
    required this._client,
    required this._apiKey,
  });

  /// Fetch chapter [chapterId]
  Future<ChaptersCompanion> getChapter(int chapterId) async {
    final res = await _client.apiChapterGet(chapterId: chapterId);

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load chapter: ${res.error}');
    }

    return res.body!.toChapterCompanion();
  }

  /// Fetch chapter cover for [chapterId]
  Future<ChapterCoversCompanion?> getChapterCover(int chapterId) async {
    final res = await _client.apiImageChapterCoverGet(
      chapterId: chapterId,
      apiKey: _apiKey,
    );

    if (!res.isSuccessful) {
      log.warning(
        'failed to download chapter cover',
        attributes: {
          'chapter_id': .int(chapterId),
          'status_code': .int(res.statusCode),
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
