import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart' hide HighlightSlot;

extension HighlightSlotDtoMappings on HighlightSlot {
  HighlightSlotsCompanion? toHighlightSlotCompanion() {
    final number = slotNumber;
    if (number == null) return null;

    final color = this.color;

    return .insert(
      slotNumber: Value(number),
      red: Value(color?.r),
      green: Value(color?.g),
      blue: Value(color?.b),
      alpha: Value(color?.a),
    );
  }
}
