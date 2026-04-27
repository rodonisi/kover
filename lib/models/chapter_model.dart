import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/utils/data_constants.dart';

part 'chapter_model.freezed.dart';
part 'chapter_model.g.dart';

@freezed
sealed class ChapterModel with _$ChapterModel {
  const ChapterModel._();

  const factory ChapterModel({
    required int id,
    required int seriesId,
    required int volumeId,
    required String title,
    required int pages,
    Format? format,
    String? summary,
    int? wordCount,
    double? avgHoursToRead,
    String? primaryColor,
    String? secondaryColor,
  }) = _ChapterModel;

  factory ChapterModel.fromJson(Map<String, Object?> json) =>
      _$ChapterModelFromJson(json);

  factory ChapterModel.fromDatabaseModel(Chapter table) {
    return ChapterModel(
      id: table.id,
      seriesId: table.seriesId,
      volumeId: table.volumeId,
      title: _cleanedTitle(table),
      pages: table.pages,
      format: table.format,
      summary: table.summary,
      wordCount: table.wordCount,
      avgHoursToRead: table.avgHoursToRead,
      primaryColor: table.primaryColor,
      secondaryColor: table.secondaryColor,
    );
  }

  static String _cleanedTitle(Chapter table) {
    if (table.title != null &&
        RegExp(
          '^(Chapter|Book) ${DataConstants.singleVolumeChapterMinNumber.toInt()}',
        ).hasMatch(table.title!)) {
      return table.titleName ?? 'Single Volume';
    }

    final titles = {
      table.title,
      table.titleName,
    }.whereType<String>().where((t) => t.trim().isNotEmpty);

    if (titles.isEmpty) {
      return switch (table.format) {
        .epub => 'Book ${table.minNumber.toInt()}',
        .image || .archive => 'Chapter ${table.minNumber.toInt()}',
        _ => 'Untitled',
      };
    }

    if (titles.length > 1 && table.titleName!.startsWith(table.title!)) {
      return table.titleName!;
    }

    return titles.join(' - ');
  }
}
