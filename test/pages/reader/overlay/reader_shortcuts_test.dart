import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/overlay/reader_shortcuts.dart';
import 'package:kover/riverpod/providers/settings/keybinds_settings.dart';

void main() {
  group('ReaderShortcuts', () {
    MockStreamHandlerEventSink? sink;
    const channel = EventChannel('kover/volume_keys');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(channel, _MockVolumeKeyHandler((eventSink) {
            sink = eventSink;
          }));
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(channel, null);
    });

    Future<void> pumpShortcuts(
      WidgetTester tester, {
      KeybindsSettingsState settings = const KeybindsSettingsState(),
      void Function()? onNextPage,
      void Function()? onPreviousPage,
    }) async {
      final container = ProviderContainer.test(
        overrides: [
          keybindsSettingsProvider.overrideWith(
            () => _FakeKeybindsSettings(settings),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ReaderShortcuts(
            onNextPage: onNextPage,
            onPreviousPage: onPreviousPage,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('hardware keys dispatch through the same manager', (
      tester,
    ) async {
      var next = 0;
      var previous = 0;
      await pumpShortcuts(
        tester,
        onNextPage: () => next++,
        onPreviousPage: () => previous++,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      expect(next, 1);
      expect(previous, 1);
    });

    testWidgets('volume key stream dispatches through the manager', (
      tester,
    ) async {
      var next = 0;
      await pumpShortcuts(
        tester,
        settings: KeybindsSettingsState(
          nextPageKey: ReaderKeyBinding(
            id: LogicalKeyboardKey.audioVolumeUp.keyId,
            keyLabel: LogicalKeyboardKey.audioVolumeUp.keyLabel,
          ),
        ),
        onNextPage: () => next++,
      );

      await tester.runAsync(() async {
        sink!.success(volumeUpKeyCode);
        // Give the event stream + riverpod listener microtasks a chance to
        // deliver through the real event loop.
        await pumpEventQueue();
      });
      await tester.pump();

      expect(next, 1);
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
