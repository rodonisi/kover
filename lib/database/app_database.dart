import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:kover/database/converters/string_list_converter.dart';
import 'package:kover/database/dao/book_dao.dart';
import 'package:kover/database/dao/chapters_dao.dart';
import 'package:kover/database/dao/collections_dao.dart';
import 'package:kover/database/dao/download_dao.dart';
import 'package:kover/database/dao/font_dao.dart';
import 'package:kover/database/dao/libraries_dao.dart';
import 'package:kover/database/migrations/migration.dart';
import 'package:kover/database/dao/reader_dao.dart';
import 'package:kover/database/dao/reading_lists_dao.dart';
import 'package:kover/database/dao/riverpod_dao.dart';
import 'package:kover/database/dao/series_dao.dart';
import 'package:kover/database/dao/series_metadata_dao.dart';
import 'package:kover/database/dao/server_settings_dao.dart';
import 'package:kover/database/dao/storage_dao.dart';
import 'package:kover/database/dao/volumes_dao.dart';
import 'package:kover/database/tables/book_info.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/collections.dart';
import 'package:kover/database/tables/download.dart';
import 'package:kover/database/tables/fonts.dart';
import 'package:kover/database/tables/libraries.dart';
import 'package:kover/database/tables/on_deck_removal.dart';
import 'package:kover/database/tables/progress.dart';
import 'package:kover/database/tables/reading_lists.dart';
import 'package:kover/database/tables/riverpod_storage.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/series_metadata.dart';
import 'package:kover/database/tables/server_settings.dart';
import 'package:kover/database/tables/sidenav.dart';
import 'package:kover/database/tables/volumes.dart';
import 'package:kover/database/tables/want_to_read.dart';
import 'package:kover/models/enums/age_rating.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/enums/library_type.dart';
import 'package:kover/models/enums/person_role.dart';
import 'package:kover/models/enums/publication_status.dart';
import 'package:kover/models/enums/sidenav_stream_type.dart';
import 'package:kover/utils/logging.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    RiverpodStorage,
    Libraries,
    Series,
    SeriesMetadata,
    SeriesCovers,
    People,
    Genres,
    Tags,
    SeriesPeopleRoles,
    SeriesGenres,
    SeriesTags,
    Volumes,
    VolumeCovers,
    Chapters,
    ChapterCovers,
    ChapterPeopleRoles,
    ChapterGenres,
    ChapterTags,
    ReadingProgress,
    BookChaptersTable,
    WantToRead,
    DownloadedPages,
    ServerSettings,
    Collections,
    CollectionSeries,
    CollectionCovers,
    ReadingLists,
    ReadingListsChapters,
    ReadingListCovers,
    Sidenav,
    OnDeckRemoval,
    Fonts,
  ],
  daos: [
    StorageDao,
    LibrariesDao,
    SeriesDao,
    SeriesMetadataDao,
    VolumesDao,
    ChaptersDao,
    ReaderDao,
    BookDao,
    DownloadDao,
    RiverpodDao,
    ServerSettingsDao,
    CollectionsDao,
    ReadingListsDao,
    FontDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  static const dbName = 'kover_db';

  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 10;

  /// Clear all content data from the database. Does not clear app state data (e.g. credentials, settings).
  /// Useful e.g. when switching user.
  Future<void> clearDb() {
    log.info('clearing database');
    return transaction(() async {
      await delete(libraries).go();
      await delete(chapters).go();
      await delete(volumes).go();
      await delete(series).go();
      await delete(seriesMetadata).go();
      await delete(wantToRead).go();
      await delete(readingProgress).go();
      await delete(bookChaptersTable).go();
      await delete(people).go();
      await delete(genres).go();
      await delete(tags).go();
      await delete(collections).go();
      await delete(collectionSeries).go();
      await delete(readingLists).go();
      await delete(readingListsChapters).go();
      await delete(onDeckRemoval).go();
      await clearDownloads();
      await clearCovers();
      await delete(fonts).go();
    });
  }

  Future<void> clearDownloads() {
    log.info('clearing downloads from database');
    return transaction(() async {
      await delete(downloadedPages).go();
    });
  }

  Future<void> clearCovers() {
    log.info('clearing covers from database');
    return transaction(() async {
      await delete(chapterCovers).go();
      await delete(volumeCovers).go();
      await delete(seriesCovers).go();
      await delete(collectionCovers).go();
      await delete(readingListCovers).go();
    });
  }

  Future<void> vacuum() async {
    await customStatement('VACUUM');
    log.info('reclaimed database space');
  }

  @override
  MigrationStrategy get migration => appDatabaseMigration(this);

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: dbName,
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
        shareAcrossIsolates: true,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
