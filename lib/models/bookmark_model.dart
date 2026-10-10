import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';

part 'bookmark_model.freezed.dart';

@freezed
class BookmarkModel({
  required final int id,
  final int? serverId,
  required final int seriesId,
  required final int volumeId,
  required final int chapterId,
  required final int page,
  final int? imageOffset,
  final String? xPath,
  required final DateTime created,
}) with _$BookmarkModel {
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
}
