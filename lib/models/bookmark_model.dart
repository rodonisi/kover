import 'package:kover/database/app_database.dart';

class BookmarkModel({
  required final int id,
  final int? serverId,
  required final int seriesId,
  required final int volumeId,
  required final int chapterId,
  required final int page,
  required final int imageOffset,
  required final String xPath,
  required final DateTime created,
}) {
  factory fromDatabaseModel(BookmarkData data) => BookmarkModel(
    id: data.id,
    serverId: data.serverId,
    seriesId: data.seriesId,
    volumeId: data.volumeId,
    chapterId: data.chapterId,
    page: data.page,
    imageOffset: data.imageOffset,
    xPath: data.xPath,
    created: data.created,
  );

  @override
  bool operator ==(Object other) =>
      other is BookmarkModel &&
      other.id == id &&
      other.page == page &&
      other.imageOffset == imageOffset &&
      other.xPath == xPath;

  @override
  int get hashCode => Object.hash(id, page, imageOffset, xPath);
}
