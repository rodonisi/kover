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

  Future<void> insertVolume(int id, {required int seriesId}) async {
    await database
        .into(database.volumes)
        .insert(
          VolumesCompanion.insert(
            id: Value(id),
            seriesId: seriesId,
            minNumber: 0,
            maxNumber: 0,
            pages: 3,
            created: DateTime.now(),
            lastModified: DateTime.now(),
          ),
        );
  }

  Future<void> insertChapter(
    int id, {
    required int volumeId,
  }) async {
    await database
        .into(database.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: Value(id),
            volumeId: volumeId,
            seriesId: 0,
            format: .epub,
            minNumber: 0,
            maxNumber: 0,
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

  group('VolumesDao watchVolumes downloadedOnly', () {
    test('returns only volumes with a downloaded page', () async {
      await insertVolume(1, seriesId: 1);
      await insertVolume(2, seriesId: 1);
      await insertVolume(3, seriesId: 1);

      await insertChapter(10, volumeId: 1);
      await insertChapter(20, volumeId: 2);

      await insertDownloadedPage(20);

      final result = await database.volumesDao
          .watchVolumes(seriesId: 1, downloadedOnly: true)
          .get();

      expect(result.map((v) => v.id).toSet(), equals({2}));
    });
  });
}
