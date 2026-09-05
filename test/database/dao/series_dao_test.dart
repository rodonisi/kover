import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/library_type.dart';

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

  Future<void> insertLibrary(int id) async {
    await database
        .into(database.libraries)
        .insert(
          LibrariesCompanion.insert(
            id: Value(id),
            name: 'lib$id',
            type: LibraryType.manga,
          ),
        );
  }

  Future<void> insertSeries(
    int id, {
    DateTime? lastSynced,
    DateTime? lastChapterAdded,
    DateTime? remoteLastRead,
  }) async {
    await database
        .into(database.series)
        .insert(
          SeriesCompanion(
            id: Value(id),
            libraryId: const Value(1),
            name: Value('name$id'),
            format: const Value(Format.epub),
            created: Value(DateTime.now()),
            lastChapterAdded: Value.absentIfNull(lastChapterAdded),
            lastSynced: Value.absentIfNull(lastSynced),
            remoteLastRead: Value.absentIfNull(remoteLastRead),
          ),
        );
  }

  group('SeriesDao', () {
    group('getOutdatedDetailsSeriesIds', () {
      test(
        'returns only series that are never synced or changed since sync',
        () async {
          await insertLibrary(1);

          final synced = DateTime(2024, 1, 1, 12);

          // never synced -> selected
          await insertSeries(1, lastSynced: null);
          // synced, no changes -> not selected
          await insertSeries(
            2,
            lastSynced: synced,
            lastChapterAdded: synced.subtract(const Duration(days: 1)),
          );
          // new chapter since sync -> selected
          await insertSeries(
            3,
            lastSynced: synced,
            lastChapterAdded: synced.add(const Duration(hours: 1)),
          );
          // new read since sync -> selected
          await insertSeries(
            4,
            lastSynced: synced,
            lastChapterAdded: synced,
            remoteLastRead: synced.add(const Duration(hours: 2)),
          );
          // unchanged -> not selected
          await insertSeries(
            5,
            lastSynced: synced,
            lastChapterAdded: synced,
            remoteLastRead: synced,
          );

          final result = await database.seriesDao.getOutdatedDetailsSeriesIds();

          expect(result.toSet(), equals({1, 3, 4}));
        },
      );
    });
  });
}
