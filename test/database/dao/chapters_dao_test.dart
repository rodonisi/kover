import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/publication_status.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertChapter(
    int id, {
    required int seriesId,
    double minNumber = 0,
    int volumeId = 0,
  }) async {
    await database
        .into(database.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: Value(id),
            volumeId: volumeId,
            seriesId: seriesId,
            format: .epub,
            minNumber: minNumber,
            maxNumber: minNumber,
            sortOrder: 0,
            ageRating: AgeRating.unknown,
            publicationStatus: PublicationStatus.unknown,
            wordCount: 0,
            releaseDate: DateTime.now(),
            created: DateTime.now(),
            lastModified: DateTime.now(),
            pages: 3,
          ),
        );
  }

  Future<void> insertDownloadedPage(int chapterId) async {
    await database
        .into(database.downloadedPages)
        .insert(
          DownloadedPagesCompanion.insert(
            chapterId: chapterId,
            page: 0,
            data: Uint8List.fromList([]),
          ),
        );
  }

  group('ChaptersDao watchFilteredChapters downloadedOnly', () {
    test('returns only chapters with a downloaded page', () async {
      await insertChapter(10, seriesId: 1);
      await insertChapter(20, seriesId: 1);
      await insertChapter(30, seriesId: 1);

      await insertDownloadedPage(20);

      final result = await database.chaptersDao
          .watchFilteredChapters(seriesId: 1, downloadedOnly: true)
          .get();

      expect(result.map((c) => c.id).toSet(), equals({20}));
    });
  });

  group('ChaptersDao watchFilteredChapters volume scope', () {
    test('keeps single-volume book chapters when scoped to a volume', () async {
      await insertChapter(10, seriesId: 1, volumeId: 1, minNumber: -100000);

      final result = await database.chaptersDao
          .watchFilteredChapters(seriesId: 1, volumeId: 1)
          .get();

      expect(result.map((c) => c.id).toSet(), equals({10}));
    });

    test('excludes single-volume book chapters at series scope', () async {
      await insertChapter(10, seriesId: 1, volumeId: 1, minNumber: -100000);
      await insertChapter(20, seriesId: 1, volumeId: 1);

      final result = await database.chaptersDao
          .watchFilteredChapters(seriesId: 1)
          .get();

      expect(result.map((c) => c.id).toSet(), equals({20}));
    });
  });
}
