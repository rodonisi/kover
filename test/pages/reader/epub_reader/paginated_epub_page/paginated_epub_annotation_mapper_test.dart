import 'package:flutter_test/flutter_test.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/models/highlight_slot_model.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_annotation_mapper.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const color = Color(0xFFFF0000);
  final slots = <HighlightSlotModel>[
    HighlightSlotModel(slotNumber: 0, color: color),
  ];

  group('toPaginatedEpubAnnotation', () {
    test('maps annotation fields and selected slot color', () {
      final mapped = toPaginatedEpubAnnotation(
        _annotation(serverId: 7, selectedSlotIndex: 0),
        slots,
      );

      expect(mapped, isNotNull);
      expect(mapped!.id, 1);
      expect(mapped.serverId, 7);
      expect(mapped.xpath, '//div/p[1]');
      expect(mapped.endXpath, '//div/p[2]');
      expect(mapped.selectedText, 'text');
      expect(mapped.color, color);
    });

    test('keeps server id null for unsynced annotations', () {
      final mapped = toPaginatedEpubAnnotation(_annotation(), slots);

      expect(mapped, isNotNull);
      expect(mapped!.serverId, isNull);
    });

    test('uses start xpath when ending xpath is missing', () {
      final mapped = toPaginatedEpubAnnotation(
        _annotation(endingXPath: null),
        slots,
      );

      expect(mapped, isNotNull);
      expect(mapped!.endXpath, '//div/p[1]');
    });

    for (final endingXPath in ['', '   ']) {
      test('uses start xpath when ending xpath is "$endingXPath"', () {
        final mapped = toPaginatedEpubAnnotation(
          _annotation(endingXPath: endingXPath),
          slots,
        );

        expect(mapped, isNotNull);
        expect(mapped!.endXpath, '//div/p[1]');
      });
    }

    for (final xPath in [null, '', '   ']) {
      test('skips annotation when xpath is "$xPath"', () {
        expect(
          toPaginatedEpubAnnotation(_annotation(xPath: xPath), slots),
          isNull,
        );
      });
    }

    for (final selectedText in [null, '', '   ']) {
      test('skips annotation when selected text is "$selectedText"', () {
        expect(
          toPaginatedEpubAnnotation(
            _annotation(selectedText: selectedText),
            slots,
          ),
          isNull,
        );
      });
    }

    test('skips annotation when selected slot is missing', () {
      expect(
        toPaginatedEpubAnnotation(_annotation(selectedSlotIndex: 1), slots),
        isNull,
      );
    });

    test('skips annotation when selected slot has no color', () {
      expect(
        toPaginatedEpubAnnotation(
          _annotation(),
          [HighlightSlotModel(slotNumber: 0)],
        ),
        isNull,
      );
    });
  });
}

AnnotationModel _annotation({
  int? serverId,
  String? xPath = '//div/p[1]',
  String? endingXPath = '//div/p[2]',
  String? selectedText = 'text',
  int selectedSlotIndex = 0,
}) {
  return AnnotationModel(
    id: 1,
    serverId: serverId,
    chapterId: 1,
    xPath: xPath,
    endingXPath: endingXPath,
    selectedText: selectedText,
    selectedSlotIndex: selectedSlotIndex,
  );
}
