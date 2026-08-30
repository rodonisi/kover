import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/server_fonts.dart';

part 'server_fonts_dao.g.dart';

@DriftAccessor(tables: [ServerFonts])
class ServerFontsDao extends DatabaseAccessor<AppDatabase>
    with _$ServerFontsDaoMixin {
  ServerFontsDao(super.attachedDatabase);

  /// Get all font ids.
  Future<List<int>> getAllIds() {
    return managers.serverFonts.map((m) => m.id).get();
  }

  /// Watch all font families.
  Stream<List<String>> watchAllFamilies() {
    final query = selectOnly(serverFonts, distinct: true)
      ..addColumns([serverFonts.family])
      ..orderBy([
        OrderingTerm(expression: serverFonts.family),
      ]);

    return query.map((row) => row.read(serverFonts.family)!).watch();
  }

  /// Get all font faces with the given [family].
  Future<List<ServerFont>> getByFamily(String family) {
    return managers.serverFonts.filter((f) => f.family.equals(family)).get();
  }

  /// Upsert [entries] batch into [ServerFonts].
  Future<void> upsert(Iterable<ServerFontsCompanion> entries) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(serverFonts, entries);
    });
  }

  /// Delete all fonts with the given [ids].
  Future<void> deleteByIds(Iterable<int> ids) async {
    await (delete(serverFonts)..where((tbl) => tbl.id.isIn(ids))).go();
  }
}
