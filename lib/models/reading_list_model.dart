import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';

part 'reading_list_model.freezed.dart';
part 'reading_list_model.g.dart';

@freezed
sealed class ReadingListModel with _$ReadingListModel {
  const factory ReadingListModel({
    required int id,
    required String title,
    String? summary,
    String? primaryColor,
    String? secondaryColor,
    DateTime? lastSynced,
    required DateTime lastModified,
    required DateTime created,
  }) = _ReadingListModel;

  factory ReadingListModel.fromJson(Map<String, Object?> json) =>
      _$ReadingListModelFromJson(json);

  factory ReadingListModel.fromDatabaseModel(ReadingList readingList) {
    return ReadingListModel(
      id: readingList.id,
      title: readingList.title,
      summary: readingList.summary,
      primaryColor: readingList.primaryColor,
      secondaryColor: readingList.secondaryColor,
      lastSynced: readingList.lastSynced,
      lastModified: readingList.lastModified,
      created: readingList.created,
    );
  }
}
