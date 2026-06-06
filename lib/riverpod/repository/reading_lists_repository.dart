import 'package:kover/database/app_database.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/reading_list_sync_operations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reading_lists_repository.g.dart';

@Riverpod(keepAlive: true)
ReadingListsRepository readingListsRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final apiKey = ref.watch(apiKeyProvider);
  final client = ReadingListSyncOperations(
    client: restClient,
    apiKey: apiKey!,
  );

  return ReadingListsRepository(db: db, client: client);
}

class ReadingListsRepository {
  final AppDatabase _db;
  final ReadingListSyncOperations _client;

  ReadingListsRepository({required this._db, required this._client});

  /// Watch all reading lists.
  Stream<List<ReadingListModel>> watchReadingLists() {
    return _db.readingListsDao.allReadingLists().watch().map(
      (lists) => lists
          .map((list) => ReadingListModel.fromDatabaseModel(list))
          .toList(),
    );
  }

  /// Watch a single reading list by [readingListId].
  Stream<ReadingListModel> watchReadingList({required int readingListId}) {
    return _db.readingListsDao
        .readingList(readingListId)
        .watchSingle()
        .map(
          (entry) => ReadingListModel.fromDatabaseModel(entry),
        );
  }

  /// Watch chapters in a reading list by [readingListId].
  Stream<List<ChapterModel>> watchReadingListChapters({
    required int readingListId,
  }) {
    return _db.readingListsDao
        .readingListChapters(readingListId: readingListId)
        .watch()
        .map(
          (chapters) => chapters.map(ChapterModel.fromDatabaseModel).toList(),
        );
  }

  /// Watch reading progress percent for a reading list by [readingListId].
  Stream<double> watchReadingListProgress({required int readingListId}) {
    return _db.readingListsDao
        .readingListProgress(readingListId: readingListId)
        .watchSingle();
  }

  /// Watch cover for a reading list by [readingListId].
  Stream<ImageModel?> watchReadingListCover({required int readingListId}) {
    return _db.readingListsDao
        .readingListCover(readingListId: readingListId)
        .watchSingleOrNull()
        .asyncMap((cover) async {
          if (cover != null) {
            return ImageModel(data: cover.image);
          }

          try {
            final remoteCover = await _client.getReadingListCover(
              readingListId,
            );
            if (remoteCover != null) {
              return ImageModel(data: remoteCover.image.value);
            }
          } catch (_) {
            return null;
          }

          return null;
        });
  }

  /// Refresh all reading lists.
  Future<void> refreshReadingLists() async {
    final readingLists = await _client.getReadingLists();

    await _db.readingListsDao.upsertReadingListsBatch(readingLists);

    for (var list in readingLists) {
      final chapters = await _client.getReadingListChapters(
        list.id.value,
      );
      await _db.readingListsDao.upsertReadingListChaptersBatch(chapters);
    }
  }

  /// Fetch all covers for reading lists missing them.
  Future<void> fetchMissingCovers() async {
    final missingIds = await _db.collectionsDao.getMissingCovers();

    final covers = [
      for (var id in missingIds) await _client.getReadingListCover(id),
    ].whereType<ReadingListCoversCompanion>();

    await _db.readingListsDao.upsertReadingListCoversBatch(covers);
  }
}
