import 'package:kover/database/app_database.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chapters_repository.g.dart';

@Riverpod(keepAlive: true)
ChaptersRepository chaptersRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final apiKey = ref.watch(apiKeyProvider);
  final client = ChapterSyncOperations(
    client: restClient,
    apiKey: apiKey ?? '',
  );

  return ChaptersRepository(db, client);
}

class ChaptersRepository {
  final AppDatabase _db;
  final ChapterSyncOperations _client;

  ChaptersRepository(this._db, this._client);

  /// Watch [chapterId]
  Stream<ChapterModel> watchChapter({
    required int chapterId,
  }) {
    return _db.chaptersDao
        .watchChapter(chapterId)
        .map(ChapterModel.fromDatabaseModel);
  }

  /// Search chapters by [query]. Optionally filter by [volumeId] and/or [seriesId]
  Future<List<ChapterModel>> searchChapters(
    String query, {
    int? volumeId,
    int? seriesId,
  }) async {
    if (query.isEmpty) return [];

    final results = await _db.chaptersDao.searchChapters(
      query,
      volumeId: volumeId,
      seriesId: seriesId,
    );

    return results.map(ChapterModel.fromDatabaseModel).toList();
  }

  /// Watch the number of pages read for [chapterId]
  Stream<int> watchPagesRead({required int chapterId}) {
    return _db.chaptersDao
        .watchPagesRead(chapterId: chapterId)
        .map((n) => n ?? 0);
  }

  /// Watch the chapter cover for [chapterId]
  Stream<ImageModel?> watchChapterCover(int chapterId) {
    return _db.chaptersDao
        .watchChapterCover(chapterId: chapterId)
        .map((cover) => cover != null ? ImageModel(data: cover.image) : null);
  }

  /// Fetch all missing chapter covers
  Future<void> fetchMissingCovers() async {
    final missing = await _db.chaptersDao.getMissingCovers();
    for (final id in missing) {
      final chapterCover = await _client.getChapterCover(id);

      if (chapterCover == null) continue;

      await _db.chaptersDao.upsertChapterCover(chapterCover);
    }
  }
}
