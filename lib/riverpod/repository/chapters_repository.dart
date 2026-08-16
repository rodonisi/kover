import 'package:kover/database/app_database.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/chapter_sync_operations.dart';
import 'package:kover/utils/chunked_fetch.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

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
        .chapter(chapterId)
        .watchSingleOrNull()
        .whereNotNull()
        .map(ChapterModel.fromDatabaseModel);
  }

  /// Watch [chapterId] combined with its relations (tags, genres, people)
  Stream<ChapterModel> watchChapterWithMetadata({
    required int chapterId,
  }) {
    final chapter = _db.chaptersDao
        .chapter(chapterId)
        .watchSingleOrNull()
        .whereNotNull();
    final relations = _db.chaptersDao.watchChapterRelations(chapterId);

    return Rx.combineLatest2(chapter, relations, (c, r) {
      return ChapterModel.fromRelations(
        ChapterModel.fromDatabaseModel(c),
        r,
      );
    });
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
        .chapterCover(chapterId: chapterId)
        .watchSingleOrNull()
        .asyncMap((
          cover,
        ) async {
          if (cover != null) {
            final image = ImageModel(data: cover.image);
            return image;
          }
          try {
            final remoteCover = await _client.getChapterCover(chapterId);
            if (remoteCover != null) {
              return ImageModel(data: remoteCover.image.value);
            }
          } catch (e, stacktrace) {
            log.error(
              'failed to fetch series cover for chapter',
              error: e,
              stacktrace: stacktrace,
              attributes: {'chapter_id': chapterId},
            );
          }

          return null;
        });
  }

  /// Fetch all missing chapter covers
  Future<void> fetchMissingCovers() async {
    final missing = await _db.chaptersDao.getMissingCovers();
    await chunkedFetch(
      items: missing,
      fetchCallback: (id) async => _client.getChapterCover(id),
      upsertCallback: (covers) async =>
          _db.chaptersDao.upsertChapterCoversBatch(
            covers.whereType<ChapterCoversCompanion>(),
          ),
    );
  }
}
