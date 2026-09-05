import 'package:kover/database/app_database.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/reading_list_sync_operations.dart';
import 'package:kover/utils/chunked_fetch.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reading_lists_repository.g.dart';

@Riverpod(keepAlive: true)
ReadingListsRepository readingListsRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final client = ReadingListSyncOperations(client: restClient);

  return ReadingListsRepository(db: db, client: client);
}

class const ReadingListsRepository({
  required final AppDatabase _db,
  required final ReadingListSyncOperations _client,
}) {
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
        .watchReadingList(readingListId)
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

    await chunkedFetch(
      items: readingLists,
      fetchCallback: (list) => _client.getReadingListChapters(list.id.value),
      upsertCallback: (batch) async {
        final flat = batch.expand((e) => e);
        await _db.readingListsDao.upsertReadingListChaptersBatch(flat);
      },
    );
  }

  /// Fetch all covers for reading lists missing them.
  Future<void> fetchMissingCovers() async {
    final missingIds = await _db.collectionsDao.getMissingCovers();

    await chunkedFetch(
      items: missingIds,
      fetchCallback: (id) => _client.getReadingListCover(id),
      upsertCallback: (batch) =>
          _db.readingListsDao.upsertReadingListCoversBatch(batch.whereType()),
    );
  }
}
