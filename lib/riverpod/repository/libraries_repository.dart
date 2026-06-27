import 'package:kover/database/app_database.dart';
import 'package:kover/models/library_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/libraries_sync_operations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'libraries_repository.g.dart';

@Riverpod(keepAlive: true)
LibrariesRepository librariesRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);

  return LibrariesRepository(
    db: db,
    client: LibrariesSyncOperations(restClient),
  );
}

class LibrariesRepository {
  final AppDatabase _db;
  final LibrariesSyncOperations _client;

  const LibrariesRepository({
    required this._db,
    required this._client,
  });

  /// Watch library [id]
  Stream<LibraryModel> watchLibrary(int id) {
    return _db.librariesDao
        .watchLibrary(id)
        .map(LibraryModel.fromDatabaseModel);
  }

  /// Watch the list of all libraries
  Stream<List<LibraryModel>> watchLibraries() {
    return _db.librariesDao.watchLibraries().map(
      (entries) => entries.map(LibraryModel.fromDatabaseModel).toList(),
    );
  }

  /// Refresh all libraries
  Future<void> refreshLibraries() async {
    final libraries = await _client.getLibraries();
    await _db.librariesDao.upsertLibraries(libraries);
  }

  /// Refresh the sidenav ordering
  Future<void> refreshSidenav() async {
    final sidenav = await _client.getSidenav();
    await _db.librariesDao.upsertSidenav(sidenav);
  }
}
