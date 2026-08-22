import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/dashboard.dart';
import 'package:kover/database/tables/libraries.dart';
import 'package:kover/database/tables/sidenav.dart';
import 'package:kover/database/tables/smart_filters.dart';
import 'package:stream_transform/stream_transform.dart';

part 'libraries_dao.g.dart';

@DriftAccessor(tables: [Libraries, Sidenav, Dashboard, SmartFilters])
class LibrariesDao extends DatabaseAccessor<AppDatabase>
    with _$LibrariesDaoMixin {
  LibrariesDao(super.attachedDatabase);

  /// Watch library [id]
  Stream<Library> watchLibrary(int id) {
    return managers.libraries
        .filter((f) => f.id(id))
        .watchSingleOrNull()
        .whereNotNull();
  }

  /// Watch all libraries stored in the db
  Stream<List<Library>> watchLibraries() {
    final q =
        select(
            libraries,
          ).join([
            leftOuterJoin(
              sidenav,
              sidenav.libraryId.equalsExp(libraries.id) &
                  sidenav.streamType.equalsValue(.library),
            ),
          ])
          ..orderBy([
            OrderingTerm.asc(sidenav.order),
            OrderingTerm.asc(libraries.name),
          ]);

    return q.watch().map((rows) {
      return rows.map((row) => row.readTable(libraries)).toList();
    });
  }

  /// Upsert [entries] and remove all libraries not present in [entries]
  Future<void> upsertLibraries(Iterable<LibrariesCompanion> entries) async {
    final ids = entries.map((e) => e.id.value).toList();
    await batch((batch) {
      batch.deleteWhere(libraries, (t) => t.id.isNotIn(ids));
      batch.insertAllOnConflictUpdate(libraries, entries);
    });
  }

  /// Upsert [entries] and remove all sidenav entries not present in [entries]
  Future<void> upsertSidenav(Iterable<SidenavCompanion> entries) async {
    final ids = entries.map((e) => e.id.value).toList();
    await batch((batch) {
      batch.deleteWhere(sidenav, (t) => t.id.isNotIn(ids));
      batch.insertAllOnConflictUpdate(sidenav, entries);
    });
  }

  /// Watch all visible dashboard entries ordered by position, with the smart
  /// filter row resolved for smart filter streams.
  Stream<List<DashboardData>> watchDashboard() {
    final query = select(dashboard)
      ..where((tbl) => tbl.visible.equals(true))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.order)]);

    return query.watch();
  }

  /// Upsert [entries] and remove all dashboard entries not present in
  /// [entries]
  Future<void> upsertDashboard(Iterable<DashboardCompanion> entries) async {
    final ids = entries.map((e) => e.id.value).toList();
    await batch((batch) {
      batch.deleteWhere(dashboard, (t) => t.id.isNotIn(ids));
      batch.insertAllOnConflictUpdate(dashboard, entries);
    });
  }
}
