import 'package:fluvita/database/app_database.dart';
import 'package:fluvita/models/enums/format.dart';
import 'package:fluvita/utils/data_constants.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter_model.freezed.dart';
part 'chapter_model.g.dart';

@freezed
sealed class ChapterModel with _$ChapterModel {
  const ChapterModel._();

  const factory ChapterModel({
    required int id,
    required int volumeId,
    required String title,
    required int pages,
    Format? format,
  }) = _ChapterModel;

  factory ChapterModel.fromJson(Map<String, Object?> json) =>
      _$ChapterModelFromJson(json);

  factory ChapterModel.fromDatabaseModel(Chapter table) {
    return ChapterModel(
      id: table.id,
      volumeId: table.volumeId,
      title: _cleanedTitle(table.title ?? table.titleName) ?? 'Untitled',
      pages: table.pages,
      format: table.format,
    );
  }

  static String? _cleanedTitle(String? title) {
    if (title != null && title.isEmpty) return null;
    if (title != null &&
        RegExp(
          '^(Chapter|Book) ${DataConstants.singleVolumeChapterMinNumber.toInt()}',
        ).hasMatch(title)) {
      return 'Single Volume';
    }

    return title;
  }
}
