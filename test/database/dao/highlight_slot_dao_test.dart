import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => db.close());

  HighlightSlotsCompanion slot(
    int slotNumber, {
    int? red,
    int? green,
    int? blue,
    double? alpha,
  }) {
    return HighlightSlotsCompanion.insert(
      slotNumber: Value(slotNumber),
      red: Value(red),
      green: Value(green),
      blue: Value(blue),
      alpha: Value(alpha),
    );
  }

  test('replaceSlots stores all slots ordered by slot number', () async {
    await db.highlightSlotDao.replaceSlots([
      slot(2, red: 0, green: 255, blue: 0, alpha: 0.5),
      slot(0, red: 255, green: 0, blue: 0, alpha: 1),
    ]);

    final slots = await db.highlightSlotDao.watchSlots().first;

    expect(slots.map((slot) => slot.slotNumber), [0, 2]);
    expect(slots.first.red, 255);
    expect(slots.first.green, 0);
    expect(slots.first.blue, 0);
    expect(slots.first.alpha, 1);
    expect(slots.last.alpha, 0.5);
  });

  test('replaceSlots removes slots that are no longer present', () async {
    await db.highlightSlotDao.replaceSlots([slot(0), slot(1)]);

    await db.highlightSlotDao.replaceSlots([slot(2)]);

    final slots = await db.highlightSlotDao.watchSlots().first;
    expect(slots.map((slot) => slot.slotNumber), [2]);
  });

  test('replaceSlots with an empty list clears all slots', () async {
    await db.highlightSlotDao.replaceSlots([slot(0)]);

    await db.highlightSlotDao.replaceSlots(const []);

    expect(await db.highlightSlotDao.watchSlots().first, isEmpty);
  });
}
