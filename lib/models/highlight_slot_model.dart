import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';
import 'package:material_ui/material_ui.dart';

part 'highlight_slot_model.freezed.dart';

@freezed
class HighlightSlotModel({
  required final int slotNumber,
  final Color? color,
}) with _$HighlightSlotModel {
  factory fromDatabaseModel(HighlightSlot data) => HighlightSlotModel(
    slotNumber: data.slotNumber,
    color: _toColor(data),
  );

  static Color? _toColor(HighlightSlot data) {
    final red = data.red;
    final green = data.green;
    final blue = data.blue;
    if (red == null || green == null || blue == null) return null;

    final alpha = ((data.alpha ?? 1.0) * 255).round().clamp(0, 255);
    return Color.fromARGB(alpha, red, green, blue);
  }
}

extension HighlightSlotListExtension on List<HighlightSlotModel> {
  Color? colorForSlot(int slotNumber) {
    return where((slot) => slot.slotNumber == slotNumber).firstOrNull?.color;
  }

  /// The slot preselected for a new annotation: Kavita's default slot `0`, or
  /// the first slot that has a color.
  int get defaultSlotNumber {
    if (colorForSlot(0) != null) return 0;

    return where((slot) => slot.color != null).firstOrNull?.slotNumber ?? 0;
  }
}
