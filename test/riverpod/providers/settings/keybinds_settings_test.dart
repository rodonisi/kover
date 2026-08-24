import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/settings/keybinds_settings.dart';

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

  group('KeybindsSettingsState', () {
    test('defaults use arrow keys', () {
      const state = KeybindsSettingsState();

      expect(state.nextPage, KeybindsSettingsState.defaultNextPage);
      expect(state.previousPage, KeybindsSettingsState.defaultPreviousPage);
      expect(
        state.nextPage.activator?.triggers.single,
        LogicalKeyboardKey.arrowRight,
      );
      expect(
        state.previousPage.activator?.triggers.single,
        LogicalKeyboardKey.arrowLeft,
      );
    });

    test('explicit bindings override defaults', () {
      const pageDown = ReaderKeyBinding(id: 9999, keyLabel: 'Page Down');
      const state = KeybindsSettingsState(nextPageKey: pageDown);

      expect(state.nextPage, pageDown);
    });

    test('assigned contains both resolved bindings', () {
      const pageDown = ReaderKeyBinding(id: 9999, keyLabel: 'Page Down');
      const state = KeybindsSettingsState(previousPageKey: pageDown);

      expect(state.assigned, {
        KeybindsSettingsState.defaultNextPage,
        pageDown,
      });
    });
  });

  group('volume keys', () {
    test('keycode mapping round trips', () {
      expect(
        volumeKeyCodeFor(LogicalKeyboardKey.audioVolumeUp),
        volumeUpKeyCode,
      );
      expect(
        volumeKeyCodeFor(LogicalKeyboardKey.audioVolumeDown),
        volumeDownKeyCode,
      );
      expect(volumeKeyCodeFor(LogicalKeyboardKey.keyA), isNull);

      expect(
        logicalKeyForVolumeKeyCode(volumeUpKeyCode),
        LogicalKeyboardKey.audioVolumeUp,
      );
      expect(
        logicalKeyForVolumeKeyCode(volumeDownKeyCode),
        LogicalKeyboardKey.audioVolumeDown,
      );
      expect(logicalKeyForVolumeKeyCode(-1), isNull);

      for (final key in capturableVolumeKeys) {
        expect(volumeKeyCodeFor(key), isNotNull);
      }
    });

    test('emits every press, including repeats of the same key', () async {
      MockStreamHandlerEventSink? sink;
      const channel = EventChannel('kover/volume_keys');
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

      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final events = <LogicalKeyboardKey>[];
      container.listen(
        volumeKeysProvider,
        (previous, next) => next.whenData((event) => events.add(event.key)),
      );

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
