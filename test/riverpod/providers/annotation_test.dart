import 'package:flutter_test/flutter_test.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/riverpod/providers/annotation.dart';
import 'package:kover/utils/extensions/color.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const yellow = Color(0x66ffff00);
  const green = Color(0x6600ff00);

  // Local ids differ from server ids: Kavita ids its highlights by server id.
  AnnotationModel annotation({required int? serverId, int slot = 0}) {
    return AnnotationModel(
      id: (serverId ?? 0) + 100,
      serverId: serverId,
      seriesId: 1,
      volumeId: 1,
      chapterId: 1,
      page: 0,
      xPath: '//body/p[1]',
      selectedText: 'text',
      selectedSlotIndex: slot,
      containsSpoiler: false,
      ownerUserId: 1,
    );
  }

  group('buildHighlightCss', () {
    test('colors each annotation by its highlight slot', () {
      final css = buildHighlightCss(
        annotations: [
          annotation(serverId: 4),
          annotation(serverId: 7, slot: 1),
        ],
        slots: [yellow, green],
      );

      expect(css['#${HtmlConstants.highlightIdPrefix}4'], {
        'background-color': yellow.toCssRgba(),
      });
      expect(css['#${HtmlConstants.highlightIdPrefix}7'], {
        'background-color': green.toCssRgba(),
      });
    });

    test('skips annotations not on the server yet', () {
      final css = buildHighlightCss(
        annotations: [annotation(serverId: null), annotation(serverId: 4)],
        slots: [yellow],
      );

      expect(css.keys, ['#${HtmlConstants.highlightIdPrefix}4']);
    });

    test('styles nothing without known annotations', () {
      final css = buildHighlightCss(annotations: [], slots: [green, yellow]);

      expect(css, isEmpty);
    });

    test('falls back to the default color without slots', () {
      final css = buildHighlightCss(
        annotations: [annotation(serverId: 4)],
        slots: [],
      );

      expect(css, {
        '#${HtmlConstants.highlightIdPrefix}4': {
          'background-color': defaultHighlightColor.toCssRgba(),
        },
      });
    });

    test('uses the first slot for a missing slot', () {
      final css = buildHighlightCss(
        annotations: [
          annotation(serverId: 4, slot: 5),
          annotation(serverId: 5, slot: -1),
        ],
        slots: [yellow, green],
      );

      expect(css.values, [
        {'background-color': yellow.toCssRgba()},
        {'background-color': yellow.toCssRgba()},
      ]);
    });
  });
}
