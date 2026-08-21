import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_repository.g.dart';

@Riverpod(keepAlive: true)
FontRepository fontRepository(Ref ref) {
  return FontRepository(
    ref.watch(databaseProvider),
    BookSyncOperations(
      client: ref.watch(restClientProvider),
      apiKey: ref.watch(apiKeyProvider)!,
    ),
  );
}

class FontRepository {
  final AppDatabase _db;
  final BookSyncOperations _client;

  const FontRepository(this._db, this._client);

  /// Returns the bytes of [font], reading them from the cache first and
  /// fetching them from the server when missing.
  Future<Uint8List?> getFontData(FontFace font) async {
    final cached = await _db.fontDao.getByUrl(url: font.url);
    if (cached != null) return cached.data;

    final fetched = await _client.getFontBytes(font.url);
    if (fetched == null || fetched.bytes.isEmpty) return null;

    return fetched.bytes;
  }

  /// Fetches any missing font in [fonts] and persists them into the db.
  Future<void> saveFonts(List<FontFace> fonts) async {
    for (final font in fonts) {
      if (await _db.fontDao.getByUrl(url: font.url) != null) continue;

      final fetched = await _client.getFontBytes(font.url);
      if (fetched == null || fetched.bytes.isEmpty) continue;

      await _db.fontDao.upsertFont(
        FontsCompanion.insert(
          family: font.family,
          weight: Value(font.weight),
          url: font.url,
          data: fetched.bytes,
          mimeType: Value(fetched.mimeType),
        ),
      );
    }
  }
}
