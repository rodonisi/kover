import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';

extension BookmarkDtoMappings on BookmarkDto {
  BookmarksCompanion toBookmarkCompanion() {
    return BookmarksCompanion.insert(
      serverId: Value(id),
      seriesId: seriesId,
      volumeId: volumeId,
      chapterId: chapterId,
      page: page,
      imageOffset: Value(imageOffset ?? -1),
      xPath: Value(xPath ?? ''),
      dirty: const Value(false),
      removed: const Value(false),
    );
  }
}

extension BookmarkDataMappings on BookmarkData {
  BookmarkDto toBookmarkDto() {
    return BookmarkDto(
      // The server's BookmarkDto declares non-nullable `Id` and `ImageOffset`,
      // so send concrete integers rather than nulls for local bookmarks.
      id: serverId ?? 0,
      page: page,
      volumeId: volumeId,
      seriesId: seriesId,
      chapterId: chapterId,
      imageOffset: imageOffset < 0 ? 0 : imageOffset,
      xPath: xPath.isEmpty ? null : xPath,
    );
  }
}
