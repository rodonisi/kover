import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/providers/breakpoints.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_reader_settings.freezed.dart';
part 'image_reader_settings.g.dart';

enum ImageScaleType {
  fitWidth,
  fitHeight,
}

enum ReaderMode {
  horizontal,
  spread,
  vertical,
}

sealed class ImageReaderSettingsLimits {
  static const double verticalReaderGapMin = 0.0;
  static const double verticalReaderGapMax = 128.0;
  static const double verticalReaderGapStep = 4.0;

  static const double verticalReaderPaddingMin = 0.0;
  static const double verticalReaderPaddingMax = 128.0;
  static const double verticalReaderPaddingStep = 4.0;

  static const double spreadReaderGapMin = 0.0;
  static const double spreadReaderGapMax = 64.0;
  static const double spreadReaderGapStep = 4.0;
}

@freezed
sealed class ImageReaderSettingsState with _$ImageReaderSettingsState {
  const factory ImageReaderSettingsState({
    @Default(ImageScaleType.fitWidth) ImageScaleType scaleType,
    @Default(ReadDirection.leftToRight) ReadDirection readDirection,
    @Default(ReaderMode.horizontal) ReaderMode readerMode,
    @Default(false) bool hadSpread,
    @Default(0.0) double verticalReaderGap,
    @Default(0.0) double verticalReaderPadding,
    @Default(0.0) double spreadReaderGap,
    @Default(true) bool spreadCoverPage,
  }) = _ImageReaderSettingsState;

  factory ImageReaderSettingsState.fromJson(Map<String, Object?> json) =>
      _$ImageReaderSettingsStateFromJson(json);
}

@riverpod
@JsonPersist()
class DefaultImageReaderSettings extends _$DefaultImageReaderSettings {
  @override
  Future<ImageReaderSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value ?? const ImageReaderSettingsState();
  }

  void setDefault(ImageReaderSettingsState newDefault) {
    state = AsyncData(newDefault);
  }
}

@riverpod
@JsonPersist()
class ImageReaderSettings extends _$ImageReaderSettings {
  @override
  Future<ImageReaderSettingsState> build({required int seriesId}) async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    final defaults = await ref.watch(defaultImageReaderSettingsProvider.future);
    ref.listen(breakpointsProvider, (prev, next) {
      final current = state.value;
      if (current == null) return;

      if (next == .compact && current.readerMode == .spread) {
        state = AsyncData(
          current.copyWith(readerMode: .horizontal),
        );
      } else if (next != .compact && current.hadSpread) {
        state = AsyncData(
          current.copyWith(readerMode: .spread),
        );
      }
    });

    return state.value ?? defaults;
  }

  Future<void> toggleScaleType() async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        scaleType: current.scaleType == .fitWidth ? .fitHeight : .fitWidth,
      ),
    );
  }

  Future<void> setReadDirection(ReadDirection direction) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        readDirection: direction,
      ),
    );
  }

  Future<void> setReaderMode(ReaderMode mode) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        readerMode: mode,
        hadSpread: mode == .spread,
      ),
    );
  }

  Future<void> setVerticalReaderGap(double gap) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        verticalReaderGap: gap.clamp(
          ImageReaderSettingsLimits.verticalReaderGapMin,
          ImageReaderSettingsLimits.verticalReaderGapMax,
        ),
      ),
    );
  }

  Future<void> setVerticalReaderPadding(double padding) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        verticalReaderPadding: padding.clamp(
          ImageReaderSettingsLimits.verticalReaderPaddingMin,
          ImageReaderSettingsLimits.verticalReaderPaddingMax,
        ),
      ),
    );
  }

  Future<void> setSpreadReaderGap(double gap) async {
    final current = await future;

    state = AsyncData(
      current.copyWith(
        spreadReaderGap: gap.clamp(
          ImageReaderSettingsLimits.spreadReaderGapMin,
          ImageReaderSettingsLimits.spreadReaderGapMax,
        ),
      ),
    );
  }

  Future<void> setSpreadCoverPage(bool value) async {
    final current = await future;

    state = AsyncData(current.copyWith(spreadCoverPage: value));
  }

  Future<void> reset() async {
    final defaults = await ref.read(defaultImageReaderSettingsProvider.future);
    state = AsyncData(defaults);
  }

  Future<void> setDefault() async {
    final current = await future;
    ref.read(defaultImageReaderSettingsProvider.notifier).setDefault(current);
  }
}
