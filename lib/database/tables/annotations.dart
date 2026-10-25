import 'package:drift/drift.dart';
import 'package:kover/database/tables/chapters.dart';
import 'package:kover/database/tables/series.dart';
import 'package:kover/database/tables/volumes.dart';

/// Epub annotations (highlights). [serverId] is null until an annotation
/// created locally is pushed to the server; [dirty] and [deleted] mark local
/// changes still to be merged with the remote state.
class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable().unique()();
  IntColumn get seriesId =>
      integer().references(Series, #id, onDelete: .cascade)();
  IntColumn get volumeId => integer().references(Volumes, #id)();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: .cascade)();
  IntColumn get page => integer()();
  TextColumn get xPath => text()();
  TextColumn get endingXPath => text().nullable()();
  TextColumn get selectedText => text()();
  TextColumn get comment => text().nullable()();
  IntColumn get selectedSlotIndex => integer()();
  BoolColumn get containsSpoiler =>
      boolean().withDefault(const Constant(false))();
  IntColumn get ownerUserId => integer()();
  DateTimeColumn get lastModified => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

/// The user's highlight colors. Annotations reference a slot by its position
/// in this list.
@DataClassName('HighlightSlotData')
class HighlightSlots extends Table {
  IntColumn get slotIndex => integer()();

  /// Color as 32-bit ARGB value.
  IntColumn get color => integer()();

  @override
  Set<Column<Object>>? get primaryKey => {slotIndex};
}
