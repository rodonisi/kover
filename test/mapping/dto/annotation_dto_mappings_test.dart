import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/mapping/dto/annotation_dto_mappings.dart';

void main() {
  final created = DateTime.utc(2026, 1, 2, 12);
  final modified = DateTime.utc(2026, 1, 3, 13);

  AnnotationDto dto({
    int? id = 9,
    String? xPath = '//div/p[1]',
    String? endingXPath = '//div/p[2]',
    String? selectedText = 'quoted text',
    int? pageNumber = 4,
    int? selectedSlotIndex = 1,
    bool? containsSpoiler = true,
    DateTime? createdUtc,
    DateTime? lastModifiedUtc,
    bool omitCreated = false,
    bool omitLastModified = false,
  }) {
    return AnnotationDto(
      id: id,
      xPath: xPath,
      endingXPath: endingXPath,
      selectedText: selectedText,
      pageNumber: pageNumber,
      selectedSlotIndex: selectedSlotIndex,
      containsSpoiler: containsSpoiler,
      chapterId: 1,
      volumeId: 2,
      seriesId: 3,
      libraryId: 4,
      ownerUserId: 5,
      createdUtc: omitCreated ? null : (createdUtc ?? created),
      lastModifiedUtc: omitLastModified ? null : (lastModifiedUtc ?? modified),
    );
  }

  group('AnnotationDtoMappings.toAnnotationCompanion', () {
    test('maps a valid remote dto', () {
      final companion = dto().toAnnotationCompanion();

      expect(companion, isNotNull);
      expect(companion!.serverId.value, 9);
      expect(companion.xPath.value, '//div/p[1]');
      expect(companion.endingXPath.value, '//div/p[2]');
      expect(companion.selectedText.value, 'quoted text');
      expect(companion.comment.value, '{}');
      expect(companion.pageNumber.value, 4);
      expect(companion.selectedSlotIndex.value, 1);
      expect(companion.containsSpoiler.value, isTrue);
      expect(companion.created.value, created);
      expect(companion.lastModified.value, modified);
    });

    for (final endingXPath in [null, '', '   ']) {
      test('falls back to xPath when endingXPath is "$endingXPath"', () {
        final companion = dto(endingXPath: endingXPath).toAnnotationCompanion();

        expect(companion, isNotNull);
        expect(companion!.endingXPath.value, '//div/p[1]');
      });
    }

    test('falls back to created when lastModifiedUtc is null', () {
      final companion = dto(omitLastModified: true).toAnnotationCompanion();

      expect(companion, isNotNull);
      expect(companion!.lastModified.value, created);
    });

    test('defaults containsSpoiler to false when null', () {
      final companion = dto(containsSpoiler: null).toAnnotationCompanion();

      expect(companion, isNotNull);
      expect(companion!.containsSpoiler.value, isFalse);
    });

    test('returns null when id is missing without a localId', () {
      expect(dto(id: null).toAnnotationCompanion(), isNull);
      expect(dto(id: null).toAnnotationCompanion(localId: 1), isNotNull);
    });

    for (final xPath in [null, '', '   ']) {
      test('returns null when xPath is "$xPath"', () {
        expect(dto(xPath: xPath).toAnnotationCompanion(), isNull);
      });
    }

    for (final selectedText in [null, '', '   ']) {
      test('returns null when selectedText is "$selectedText"', () {
        expect(dto(selectedText: selectedText).toAnnotationCompanion(), isNull);
      });
    }

    test('returns null when required scalar fields are missing', () {
      expect(dto(pageNumber: null).toAnnotationCompanion(), isNull);
      expect(dto(selectedSlotIndex: null).toAnnotationCompanion(), isNull);
      expect(dto(omitCreated: true).toAnnotationCompanion(), isNull);
    });
  });
}
