import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_overlay_provider.freezed.dart';
part 'reader_overlay_provider.g.dart';

@freezed
class ReaderOverlayModel({
  required final ReaderState reader,
  required final bool showProgressBar,
}) with _$ReaderOverlayModel;

@riverpod
Future<ReaderOverlayModel> readerOverlay(
  Ref ref, {
  required int seriesId,
  int? chapterId,
  int? readingListId,
}) async {
  final reader = await ref.watch(
    readerProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    ).future,
  );
  final showProgressBar = await ref.watch(
    commonReaderSettingsProvider(seriesId: seriesId)
        .selectAsync((state) => state.showProgressBar),
  );

  return ReaderOverlayModel(reader: reader, showProgressBar: showProgressBar);
}
