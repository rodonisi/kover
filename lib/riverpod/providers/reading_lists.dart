import 'package:kover/models/chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/reading_list_model.dart';
import 'package:kover/riverpod/repository/reading_lists_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reading_lists.g.dart';

@riverpod
Stream<List<ReadingListModel>> readingLists(Ref ref) {
  final readingListsRepository = ref.watch(readingListsRepositoryProvider);
  return readingListsRepository.watchReadingLists();
}

@riverpod
Stream<ReadingListModel> readingList(Ref ref, {required int readingListId}) {
  final readingListsRepository = ref.watch(readingListsRepositoryProvider);
  return readingListsRepository.watchReadingList(readingListId: readingListId);
}

@riverpod
Stream<List<ChapterModel>> readingListChapters(
  Ref ref, {
  required int readingListId,
}) {
  final readingListsRepository = ref.watch(readingListsRepositoryProvider);
  return readingListsRepository.watchReadingListChapters(
    readingListId: readingListId,
  );
}

@riverpod
Stream<double> readingListProgress(Ref ref, {required int readingListId}) {
  final readingListsRepository = ref.watch(readingListsRepositoryProvider);
  return readingListsRepository.watchReadingListProgress(
    readingListId: readingListId,
  );
}

@riverpod
Stream<ImageModel?> readingListCover(Ref ref, {required int readingListId}) {
  final readingListsRepository = ref.watch(readingListsRepositoryProvider);
  return readingListsRepository.watchReadingListCover(
    readingListId: readingListId,
  );
}
