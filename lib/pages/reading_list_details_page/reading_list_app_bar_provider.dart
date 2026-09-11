import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reading_list_app_bar_provider.freezed.dart';
part 'reading_list_app_bar_provider.g.dart';

@freezed
class ReadingListAppBarModel({
  required final ChapterModel chapter,
  required final bool canRead,
}) with _$ReadingListAppBarModel;

@riverpod
Future<ReadingListAppBarModel> readingListAppBar(
  Ref ref, {
  required int readingListId,
}) async {
  final chapter = await ref.watch(
    readingListContinuePointProvider(readingListId: readingListId).future,
  );
  final canRead = await ref.watch(
    canReadReadingListProvider(readingListId).future,
  );

  return ReadingListAppBarModel(
    chapter: chapter,
    canRead: canRead,
  );
}
