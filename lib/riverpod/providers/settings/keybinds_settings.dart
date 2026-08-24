import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'keybinds_settings.freezed.dart';
part 'keybinds_settings.g.dart';

@freezed
sealed class ReaderKeyBinding with _$ReaderKeyBinding {
  const ReaderKeyBinding._();

  const factory ReaderKeyBinding({
    required int id,
    required String keyLabel,
    @Default(false) bool control,
    @Default(false) bool alt,
    @Default(false) bool shift,
    @Default(false) bool meta,
  }) = _ReaderKeyBinding;

  factory ReaderKeyBinding.fromJson(Map<String, Object?> json) =>
      _$ReaderKeyBindingFromJson(json);

  LogicalKeyboardKey? get key => LogicalKeyboardKey.findKeyByKeyId(id);

  bool get isVolumeKey =>
      id == LogicalKeyboardKey.audioVolumeUp.keyId ||
      id == LogicalKeyboardKey.audioVolumeDown.keyId;

  SingleActivator? get activator {
    final logicalKey = key;

    if (logicalKey == null) return null;

    return SingleActivator(
      logicalKey,
      control: control,
      alt: alt,
      shift: shift,
      meta: meta,
    );
  }

  String get label => [
    if (control) 'Ctrl',
    if (alt) 'Alt',
    if (shift) 'Shift',
    if (meta) 'Super',
    keyLabel,
  ].join(' + ');
}

@freezed
sealed class KeybindsSettingsState with _$KeybindsSettingsState {
  const KeybindsSettingsState._();

  const factory KeybindsSettingsState({
    ReaderKeyBinding? nextPageKey,
    ReaderKeyBinding? previousPageKey,
  }) = _KeybindsSettingsState;

  factory fromJson(Map<String, dynamic> json) =>
      _$KeybindsSettingsStateFromJson(json);

  static ReaderKeyBinding get defaultNextPage => ReaderKeyBinding(
    id: LogicalKeyboardKey.arrowRight.keyId,
    keyLabel: LogicalKeyboardKey.arrowRight.keyLabel,
  );

  static ReaderKeyBinding get defaultPreviousPage => ReaderKeyBinding(
    id: LogicalKeyboardKey.arrowLeft.keyId,
    keyLabel: LogicalKeyboardKey.arrowLeft.keyLabel,
  );

  ReaderKeyBinding get nextPage => nextPageKey ?? defaultNextPage;

  ReaderKeyBinding get previousPage => previousPageKey ?? defaultPreviousPage;

  Set<ReaderKeyBinding> get assigned => {nextPage, previousPage};
}

@riverpod
@JsonPersist()
class KeybindsSettings extends _$KeybindsSettings {
  @override
  Future<KeybindsSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    return state.value ?? const KeybindsSettingsState();
  }

  Future<void> setNextPageKey(ReaderKeyBinding value) async {
    final current = await future;
    state = .data(current.copyWith(nextPageKey: value));
    log.info('set next page keybind', attributes: {'value': value.label});
  }

  Future<void> setPreviousPageKey(ReaderKeyBinding value) async {
    final current = await future;
    state = .data(current.copyWith(previousPageKey: value));
    log.info('set previous page keybind', attributes: {'value': value.label});
  }
}

/// Android keycodes for the volume keys.
const volumeUpKeyCode = 24;
const volumeDownKeyCode = 25;

/// All volume keys that can be captured and bound.
final capturableVolumeKeys = {
  LogicalKeyboardKey.audioVolumeUp,
  LogicalKeyboardKey.audioVolumeDown,
};

const _captureChannel = MethodChannel('kover/volume_key_capture');

int? volumeKeyCodeFor(LogicalKeyboardKey key) => switch (key) {
  .audioVolumeUp => volumeUpKeyCode,
  .audioVolumeDown => volumeDownKeyCode,
  _ => null,
};

LogicalKeyboardKey? logicalKeyForVolumeKeyCode(int keyCode) =>
    switch (keyCode) {
      volumeUpKeyCode => .audioVolumeUp,
      volumeDownKeyCode => .audioVolumeDown,
      _ => null,
    };

/// Sets which volume keys the platform should capture and emit through
/// [volumeKeysProvider] instead of letting the system handle them.
///
/// Only supported on Android; a no-op on other platforms.
Future<void> setCapturedVolumeKeys(Set<LogicalKeyboardKey> keys) async {
  try {
    await _captureChannel.invokeMethod<void>(
      'setCapturedKeys',
      keys.map(volumeKeyCodeFor).nonNulls.toList(),
    );
  } on MissingPluginException {
    // Volume key capture is only implemented on Android.
  }
}

/// A single volume key press.
final class const VolumeKeyEvent(final LogicalKeyboardKey key) {
  /// A synthetic [KeyDownEvent] for dispatching through a [ShortcutManager].
  KeyDownEvent toKeyDownEvent() => KeyDownEvent(
    physicalKey: switch (key) {
      .audioVolumeUp => PhysicalKeyboardKey.audioVolumeUp,
      _ => PhysicalKeyboardKey.audioVolumeDown,
    },
    logicalKey: key,
    timeStamp: Duration.zero,
    synthesized: true,
  );
}

@riverpod
Stream<VolumeKeyEvent> volumeKeys(Ref ref) {
  final controller = StreamController<VolumeKeyEvent>();

  final subscription = const EventChannel('kover/volume_keys')
      .receiveBroadcastStream()
      .listen(
        (data) {
          if (data case final int keyCode) {
            final key = logicalKeyForVolumeKeyCode(keyCode);
            if (key != null) controller.add(VolumeKeyEvent(key));
          }
        },
        onError: (Object error) {},
      );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
}
