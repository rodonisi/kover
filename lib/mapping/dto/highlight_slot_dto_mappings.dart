import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart' hide HighlightSlot;

extension HighlightSlotDtoMappings on HighlightSlot {
  /// Convert this slot to a database companion. Slots without a slot number
  /// cannot be addressed by annotations and are skipped.
  HighlightSlotsCompanion? toHighlightSlotCompanion() {
    final number = slotNumber;
    if (number == null) return null;

    final color = this.color;

    return HighlightSlotsCompanion.insert(
      slotNumber: Value(number),
      red: Value(color?.r),
      green: Value(color?.g),
      blue: Value(color?.b),
      alpha: Value(color?.a),
    );
  }
}
