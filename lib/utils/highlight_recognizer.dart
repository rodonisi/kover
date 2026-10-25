import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Marks the text of a Kavita highlight with the server id of its annotation.
///
/// Without callbacks it takes no part in the gesture arena: the reader overlay
/// lies above the content and wins every tap, then looks the highlight up with
/// [highlightAt]. It is a [TapGestureRecognizer] because text semantics only
/// accept tap and long press recognizers.
class HighlightRecognizer extends TapGestureRecognizer {
  final int annotationId;

  HighlightRecognizer(this.annotationId);
}

/// Returns the server id of the annotation highlighted under [globalPosition]
/// in the view of [context], or null when no highlighted text is there.
int? highlightAt(BuildContext context, Offset globalPosition) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(
    result,
    globalPosition,
    View.of(context).viewId,
  );

  // Paragraphs add the span under the position only when it hits a glyph.
  for (final entry in result.path) {
    if (entry.target case TextSpan(
      :final HighlightRecognizer recognizer,
    )) {
      return recognizer.annotationId;
    }
  }
  return null;
}
