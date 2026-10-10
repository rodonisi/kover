import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';

extension BookmarkDtoMappings on BookmarkDto {
  BookmarksCompanion toBookmarkCompanion() {
    return BookmarksCompanion.insert(
      serverId: .absentIfNull(id),
      seriesId: seriesId,
      volumeId: volumeId,
      chapterId: chapterId,
      page: page,
      imageOffset: .absentIfNull(imageOffset),
      xPath: .absentIfNull(xPath),
    );
  }
}

extension BookmarkDataMappings on BookmarkData {
  BookmarkDto toBookmarkDto() {
    return BookmarkDto(
      id: serverId,
      page: page,
      volumeId: volumeId,
      seriesId: seriesId,
      chapterId: chapterId,
      imageOffset: imageOffset,
      xPath: xPath,
    );
  }
}
