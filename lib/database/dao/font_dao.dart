import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/fonts.dart';

part 'font_dao.g.dart';

@DriftAccessor(tables: [Fonts])
class FontDao extends DatabaseAccessor<AppDatabase> with _$FontDaoMixin {
  FontDao(super.attachedDatabase);

  /// Looks up a cached font by its deduplication key.
  Future<Font?> getByUrl({required String url}) {
    return (select(
      fonts,
    )..where((tbl) => tbl.url.equals(url))).getSingleOrNull();
  }

  /// Persists a font. Replaces any existing entry with the same [url].
  Future<void> upsertFont(FontsCompanion entry) {
    return into(fonts).insert(
      entry,
      onConflict: DoUpdate(
        (_) => entry,
        target: [fonts.url],
      ),
    );
  }
}
