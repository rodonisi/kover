import 'package:flutter_test/flutter_test.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/bookmark_dto_mappings.dart';

void main() {
  test('BookmarkDto maps to companion preserving fields', () {
    const dto = BookmarkDto(
      id: 7,
      page: 3,
      volumeId: 2,
      seriesId: 1,
      chapterId: 9,
      imageOffset: 1,
      xPath: '//div[1]',
    );
    final companion = dto.toBookmarkCompanion();
    expect(companion.serverId.value, 7);
    expect(companion.page.value, 3);
    expect(companion.xPath.value, '//div[1]');
    expect(companion.imageOffset.value, 1);
    expect(companion.dirty.value, isFalse);
    expect(companion.removed.value, isFalse);
  });

  test('null imageOffset and xPath normalize to defaults', () {
    const dto = BookmarkDto(
      page: 0,
      volumeId: 1,
      seriesId: 1,
      chapterId: 1,
    );
    final companion = dto.toBookmarkCompanion();
    expect(companion.imageOffset.value, -1);
    expect(companion.xPath.value, '');
  });

  test('BookmarkData maps back to DTO', () {
    final data = BookmarkData(
      id: 1,
      serverId: 7,
      seriesId: 1,
      volumeId: 2,
      chapterId: 9,
      page: 3,
      imageOffset: 1,
      xPath: '//div[1]',
      created: DateTime(2026),
      dirty: false,
      removed: false,
    );
    final dto = data.toBookmarkDto();
    expect(dto.id, 7);
    expect(dto.imageOffset, 1);
    expect(dto.xPath, '//div[1]');
  });

  test('null serverId maps to a zero id', () {
    final data = BookmarkData(
      id: 1,
      seriesId: 1,
      volumeId: 2,
      chapterId: 9,
      page: 0,
      imageOffset: 1,
      xPath: '//div[1]',
      created: DateTime(2026),
      dirty: true,
      removed: false,
    );
    expect(data.toBookmarkDto().id, 0);
  });

  test('empty xPath maps back to null and -1 imageOffset to 0', () {
    final data = BookmarkData(
      id: 1,
      seriesId: 1,
      volumeId: 2,
      chapterId: 9,
      page: 0,
      imageOffset: -1,
      xPath: '',
      created: DateTime(2026),
      dirty: false,
      removed: false,
    );
    final dto = data.toBookmarkDto();
    expect(dto.xPath, isNull);
    expect(dto.imageOffset, 0);
  });

  test('local image bookmark serializes non-null ints', () {
    final data = BookmarkData(
      id: 1,
      seriesId: 1,
      volumeId: 2,
      chapterId: 9,
      page: 0,
      imageOffset: -1,
      xPath: '//div[1]',
      created: DateTime(2026),
      dirty: true,
      removed: false,
    );
    final json = data.toBookmarkDto().toJson();
    expect(json['id'], isA<int>());
    expect(json['id'], isNotNull);
    expect(json['imageOffset'], isA<int>());
    expect(json['imageOffset'], isNotNull);
  });
}
