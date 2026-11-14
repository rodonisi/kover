import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/highlight_slots.dart';

part 'highlight_slot_dao.g.dart';

@DriftAccessor(tables: [HighlightSlots])
class HighlightSlotDao extends DatabaseAccessor<AppDatabase>
    with _$HighlightSlotDaoMixin {
  HighlightSlotDao(super.attachedDatabase);

  /// Watch all locally stored highlight slots, ordered by slot number.
  Stream<List<HighlightSlot>> watchSlots() {
    return (select(
      highlightSlots,
    )..orderBy([(s) => OrderingTerm.asc(s.slotNumber)])).watch();
  }

  /// Replace all locally stored highlight slots with [slots].
  Future<void> replaceSlots(Iterable<HighlightSlotsCompanion> slots) {
    return transaction(() async {
      await delete(highlightSlots).go();
      final entries = slots.toList();
      if (entries.isEmpty) return;
      await batch((batch) => batch.insertAll(highlightSlots, entries));
    });
  }
}
