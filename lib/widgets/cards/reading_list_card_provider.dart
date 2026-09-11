import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/reading_lists.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reading_list_card_provider.freezed.dart';
part 'reading_list_card_provider.g.dart';

@freezed
class ReadingListCardModel({
  required final ReadingListModel readingList,
  required final ChapterModel continuePoint,
  required final bool canRead,
}) with _$ReadingListCardModel;

@riverpod
Future<ReadingListCardModel> readingListCard(
  Ref ref, {
  required int readingListId,
}) async {
  final readingList = await ref.watch(
    readingListProvider(readingListId: readingListId).future,
  );
  final continuePoint = await ref.watch(
    readingListContinuePointProvider(readingListId: readingListId).future,
  );
  final canRead = await ref.watch(
    canReadReadingListProvider(readingListId).future,
  );

  return ReadingListCardModel(
    readingList: readingList,
    continuePoint: continuePoint,
    canRead: canRead,
  );
}
