import 'package:kover/models/annotation_model.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'annotation.g.dart';

/// Kavita's default color for the first highlight slot, used while the user's
/// highlight slots are unknown.
const defaultHighlightColor = Color.fromRGBO(0, 255, 255, 0.4);

@riverpod
Stream<List<AnnotationModel>> seriesAnnotations(
  Ref ref, {
  required int seriesId,
}) {
  return ref
      .watch(annotationRepositoryProvider)
      .watchSeriesAnnotations(seriesId: seriesId);
}

@riverpod
Stream<List<Color>> highlightSlots(Ref ref) {
  return ref.watch(annotationRepositoryProvider).watchHighlightSlots();
}

/// Styles for the highlights Kavita injects into the epub pages of
/// [seriesId], colored by the highlight slot of their annotation.
@riverpod
Future<Map<String, Map<String, String>>> highlightCss(
  Ref ref, {
  required int seriesId,
}) async {
  final annotations = await ref.watch(
    seriesAnnotationsProvider(seriesId: seriesId).future,
  );
  final slots = await ref.watch(highlightSlotsProvider.future);

  return buildHighlightCss(annotations: annotations, slots: slots);
}

/// Builds the highlight styles keyed by id selector, one per known annotation
/// colored by its slot. Highlights without a known annotation stay unstyled:
/// downloaded pages keep the highlights of annotations deleted since.
Map<String, Map<String, String>> buildHighlightCss({
  required List<AnnotationModel> annotations,
  required List<Color> slots,
}) {
  Color slotColor(int index) => index >= 0 && index < slots.length
      ? slots[index]
      : slots.firstOrNull ?? defaultHighlightColor;

  return {
    for (final annotation in annotations)
      '#${HtmlConstants.highlightIdPrefix}${annotation.id}': {
        'background-color': slotColor(
          annotation.selectedSlotIndex,
        ).toCssRgba(),
      },
  };
}
