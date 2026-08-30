import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/font_sync_operations.dart';
import 'package:kover/utils/chunked_fetch.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_fonts_repository.g.dart';

@Riverpod(keepAlive: true)
ServerFontsRepository serverFontsRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final client = FontSyncOperations(client: restClient);

  return ServerFontsRepository(db: db, client: client);
}

class ServerFontsRepository({
  required final AppDatabase _db,
  required final FontSyncOperations _client,
}) {
  /// Watch all synced server fonts.
  Stream<List<String>> watchServerFontFamilies() {
    return _db.serverFontsDao.watchAllFamilies();
  }

  /// Get all font faces with the given [family].
  Future<List<Uint8List>> getBytesByFamily(String family) async {
    final rows = await _db.serverFontsDao.getByFamily(family);
    return rows.map((row) => row.data).toList();
  }

  /// Fetch server fonts metadata and bytes from the server and store them in
  /// the database
  Future<void> refreshServerFonts() async {
    final fontCompanions = await _client.getServerFonts();
    final downloadedFontsIds = await _db.serverFontsDao.getAllIds();

    final delta = fontCompanions.where(
      (font) => !downloadedFontsIds.contains(font.id.value),
    );

    final removeDelta = downloadedFontsIds.where(
      (id) => !fontCompanions.any((font) => font.id.value == id),
    );

    await chunkedFetch(
      items: delta,
      fetchCallback: (item) async {
        final bytes = await _client.getServerFontBytes(item.id.value);
        if (bytes == null) return null;

        return item.copyWith(data: Value(bytes.bytes));
      },
      upsertCallback: (batch) async {
        final insert = batch.whereType<ServerFontsCompanion>();
        await _db.serverFontsDao.upsert(insert);
      },
    );

    await _db.serverFontsDao.deleteByIds(removeDelta);
  }
}
