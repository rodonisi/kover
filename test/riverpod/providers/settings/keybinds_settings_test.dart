import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/platform.dart';
import 'package:kover/riverpod/providers/settings/keybinds_settings.dart';
import 'package:kover/utils/constants/platform_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderKeyBinding', () {
    test('json round trip preserves all fields', () {
      final binding = ReaderKeyBinding(
        id: LogicalKeyboardKey.arrowRight.keyId,
        keyLabel: LogicalKeyboardKey.arrowRight.keyLabel,
        control: true,
      );

      final result = ReaderKeyBinding.fromJson(binding.toJson());

      expect(result, binding);
      expect(result.control, isTrue);
    });

    test('activator resolves known keys with modifiers', () {
      final activator = ReaderKeyBinding(
        id: LogicalKeyboardKey.pageDown.keyId,
        keyLabel: LogicalKeyboardKey.pageDown.keyLabel,
        shift: true,
      ).activator;

      expect(activator?.triggers.single, LogicalKeyboardKey.pageDown);
      expect(activator?.shift, isTrue);
      expect(activator?.control, isFalse);
    });

    test('activator returns null for unknown keys', () {
      expect(const ReaderKeyBinding(id: -1, keyLabel: '?').activator, isNull);
    });

    test('label prefixes modifiers onto the stored key label', () {
      final arrowRight = LogicalKeyboardKey.arrowRight;
      final keyA = LogicalKeyboardKey.keyA;

      expect(
        ReaderKeyBinding(
          id: arrowRight.keyId,
          keyLabel: arrowRight.keyLabel,
        ).label,
        'Arrow Right',
      );
      expect(
        ReaderKeyBinding(
          id: keyA.keyId,
          keyLabel: keyA.keyLabel,
          control: true,
        ).label,
        'Ctrl + A',
      );
      expect(
        const ReaderKeyBinding(id: 1, keyLabel: 'Digit1', alt: true).label,
        'Alt + Digit1',
      );
    });

    test('isVolumeKey identifies volume keys', () {
      expect(
        ReaderKeyBinding(
          id: LogicalKeyboardKey.audioVolumeUp.keyId,
          keyLabel: LogicalKeyboardKey.audioVolumeUp.keyLabel,
        ).isVolumeKey,
        isTrue,
      );
      expect(
        ReaderKeyBinding(
          id: LogicalKeyboardKey.audioVolumeDown.keyId,
          keyLabel: LogicalKeyboardKey.audioVolumeDown.keyLabel,
        ).isVolumeKey,
        isTrue,
      );
      expect(
        ReaderKeyBinding(
          id: LogicalKeyboardKey.keyA.keyId,
          keyLabel: LogicalKeyboardKey.keyA.keyLabel,
        ).isVolumeKey,
        isFalse,
      );
    });

    test('key getter resolves the logical key by id', () {
      expect(
        ReaderKeyBinding(
          id: LogicalKeyboardKey.escape.keyId,
          keyLabel: LogicalKeyboardKey.escape.keyLabel,
        ).key,
        LogicalKeyboardKey.escape,
      );
    });
  });

  group('volume keys', () {
    test('emits every press, including repeats of the same key', () async {
      MockStreamHandlerEventSink? sink;
      const channel = PlatformChannels.volumeKeys;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            channel,
            _MockVolumeKeyHandler((eventSink) {
              sink = eventSink;
            }),
          );

      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(channel, null),
      );

      final container = ProviderContainer.test(
        overrides: [
          appPlatformProvider.overrideWithValue(AppPlatform.android),
          keybindsSettingsProvider.overrideWith(
            () => _FakeKeybindsSettings(const KeybindsSettingsState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final events = <LogicalKeyboardKey>[];
      container.listen(
        volumeKeysProvider(),
        (previous, next) => next.whenData((event) => events.add(event.key)),
      );
      await pumpEventQueue();

      sink!.success(volumeUpKeyCode);
      sink!.success(volumeUpKeyCode);
      await pumpEventQueue();

      expect(events, [
        LogicalKeyboardKey.audioVolumeUp,
        LogicalKeyboardKey.audioVolumeUp,
      ]);
    });
  });
}

class _FakeKeybindsSettings extends KeybindsSettings {
  _FakeKeybindsSettings(this._settings);

  final KeybindsSettingsState _settings;

  @override
  Future<KeybindsSettingsState> build() async => _settings;
}

class _MockVolumeKeyHandler extends MockStreamHandler {
  _MockVolumeKeyHandler(this.onListenCallback);

  final void Function(MockStreamHandlerEventSink events) onListenCallback;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    onListenCallback(events);
  }

  @override
  void onCancel(Object? arguments) {}
}
