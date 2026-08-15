import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chapter_app_bar_provider.freezed.dart';
part 'chapter_app_bar_provider.g.dart';

@freezed
sealed class ChapterInfoState with _$ChapterInfoState {
  const factory ChapterInfoState({
    required ChapterModel chapter,
    required ChapterMetadataModel metadata,
  }) = _ChapterInfoState;
}

@riverpod
Future<ChapterInfoState> chapterInfo(
  Ref ref, {
  required int chapterId,
}) async {
  final chapter = await ref.watch(chapterProvider(chapterId: chapterId).future);
  final metadata = await ref.watch(
    chapterMetadataProvider(chapterId: chapterId).future,
  );

  return ChapterInfoState(
    chapter: chapter,
    metadata: metadata,
  );
}
