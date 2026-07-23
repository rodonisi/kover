import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        // Recommended for widget tests to avoid test errors.
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('DownloadDao', () {
    group('isChapterDownloaded', () {
      test(
        'when all pages of a chapter are downloaded, then returns true',
        () {
          fakeAsync((async) {
            bool? result;
            const chapterId = 0;

            database
                .into(database.chapters)
                .insert(
                  ChaptersCompanion.insert(
                    id: const Value(chapterId),
                    volumeId: 0,
                    seriesId: 0,
                    format: .epub,
                    minNumber: 0,
                    maxNumber: 0,
                    sortOrder: 0,
                    wordCount: 0,
                    releaseDate: DateTime.now(),
                    created: DateTime.now(),
                    lastModified: DateTime.now(),
                    pages: 3,
                  ),
                );

            for (var i = 0; i < 3; i++) {
              database
                  .into(database.downloadedPages)
                  .insert(
                    DownloadedPagesCompanion.insert(
                      chapterId: chapterId,
                      page: i,
                      data: Uint8List.fromList([]),
                    ),
                  );
            }

            database.downloadDao
                .isChapterDownloaded(chapterId: chapterId)
                .getSingle()
                .then((v) => result = v);

            async.flushMicrotasks();

            expect(result, isTrue);
          });
        },
      );

      test(
        'when a pdf format has one page of one downloaded, then returns true',
        () {
          fakeAsync((async) {
            bool? result;
            const chapterId = 0;

            database
                .into(database.chapters)
                .insert(
                  ChaptersCompanion.insert(
                    id: const Value(chapterId),
                    volumeId: 0,
                    seriesId: 0,
                    format: .pdf,
                    minNumber: 0,
                    maxNumber: 0,
                    sortOrder: 0,
                    wordCount: 0,
                    releaseDate: DateTime.now(),
                    created: DateTime.now(),
                    lastModified: DateTime.now(),
                    pages: 3,
                  ),
                );

            database
                .into(database.downloadedPages)
                .insert(
                  DownloadedPagesCompanion.insert(
                    chapterId: chapterId,
                    page: 0,
                    data: Uint8List.fromList([]),
                  ),
                );

            database.downloadDao
                .isChapterDownloaded(chapterId: chapterId)
                .getSingle()
                .then((v) => result = v);

            async.flushMicrotasks();

            expect(result, isTrue);
          });
        },
      );

      test(
        'when not all pages of a chapter are downloaded, then returns false',
        () {
          fakeAsync((async) {
            bool? result;
            const chapterId = 0;

            database
                .into(database.chapters)
                .insert(
                  ChaptersCompanion.insert(
                    id: const Value(chapterId),
                    volumeId: 0,
                    seriesId: 0,
                    format: .epub,
                    minNumber: 0,
                    maxNumber: 0,
                    sortOrder: 0,
                    wordCount: 0,
                    releaseDate: DateTime.now(),
                    created: DateTime.now(),
                    lastModified: DateTime.now(),
                    pages: 3,
                  ),
                );

            for (var i = 0; i < 2; i++) {
              database
                  .into(database.downloadedPages)
                  .insert(
                    DownloadedPagesCompanion.insert(
                      chapterId: chapterId,
                      page: i,
                      data: Uint8List.fromList([]),
                    ),
                  );
            }

            database.downloadDao
                .isChapterDownloaded(chapterId: chapterId)
                .getSingle()
                .then((v) => result = v);

            async.flushMicrotasks();

            expect(result, isFalse);
          });
        },
      );

      test(
        'when a pdf is not downloaded, then returns false',
        () {
          fakeAsync((async) {
            bool? result;
            const chapterId = 0;

            database
                .into(database.chapters)
                .insert(
                  ChaptersCompanion.insert(
                    id: const Value(chapterId),
                    volumeId: 0,
                    seriesId: 0,
                    format: .pdf,
                    minNumber: 0,
                    maxNumber: 0,
                    sortOrder: 0,
                    wordCount: 0,
                    releaseDate: DateTime.now(),
                    created: DateTime.now(),
                    lastModified: DateTime.now(),
                    pages: 3,
                  ),
                );

            database.downloadDao
                .isChapterDownloaded(chapterId: chapterId)
                .getSingle()
                .then((v) => result = v);

            async.flushMicrotasks();

            expect(result, isFalse);
          });
        },
      );
    });
  });
}
