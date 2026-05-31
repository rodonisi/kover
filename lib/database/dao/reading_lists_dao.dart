import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/reading_lists.dart';

part 'reading_lists_dao.g.dart';

@DriftAccessor(tables: [ReadingLists, ReadingListChapters, ReadingListCovers])
class ReadingListsDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingListsDaoMixin {
  ReadingListsDao(super.attachedDatabase);

  /// Upsert a batch of reading lists. Removes all entries not present in the batch.
  Future<void> upsertReadingListsBatch(
    Iterable<ReadingListsCompanion> entries,
  ) async {
    final ids = entries.map((e) => e.id.value).toList();
    final delta = await managers.readingLists
        .filter((f) => f.id.not.isIn(ids))
        .map((m) => m.id)
        .get();
    await transaction(() async {
      await (delete(readingLists)..where((t) => t.id.isIn(delta))).go();
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          readingLists,
          entries.toList(),
        );
      });
    });
  }

  /// Upsert a batch of reading list chapters.
  Future<void> upsertReadingListChaptersBatch(
    Iterable<ReadingListChaptersCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        readingListChapters,
        entries.toList(),
      );
    });
  }

  /// Upsert a batch of reading list covers.
  Future<void> upsertReadingListCoversBatch(
    Iterable<ReadingListCoversCompanion> entries,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        readingListCovers,
        entries.toList(),
      );
    });
  }
}
