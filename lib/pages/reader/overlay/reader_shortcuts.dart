import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/settings/keybinds_settings.dart';

class NextPageIntent extends Intent {
  const NextPageIntent();
}

class PreviousPageIntent extends Intent {
  const PreviousPageIntent();
}

/// Exposes [ShortcutManager.handleKeypress] so synthetic key events (volume
/// keys captured natively) can use the same dispatch path as hardware keys.
final class _ReaderShortcutManager({super.shortcuts}) extends ShortcutManager {
  KeyEventResult injectKeyEvent(BuildContext context, KeyEvent event) {
    return handleKeypress(context, event);
  }
}

/// Handles the reader's keyboard shortcuts and natively captured volume keys
/// through a single [ShortcutManager].
class ReaderShortcuts extends HookConsumerWidget {
  final void Function()? onNextPage;
  final void Function()? onPreviousPage;
  final Widget child;

  const ReaderShortcuts({
    super.key,
    this.onNextPage,
    this.onPreviousPage,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyBindings = ref.watch(keybindsSettingsProvider);

    final nextPageIntent = const NextPageIntent();
    final previousPageIntent = const PreviousPageIntent();

    final shortcuts = <ShortcutActivator, Intent>{
      ?keyBindings.value?.nextPage.activator: nextPageIntent,
      ?keyBindings.value?.previousPage.activator: previousPageIntent,
    };

    final manager = useMemoized(
      () => _ReaderShortcutManager(shortcuts: shortcuts),
    );

    useEffect(() {
      manager.shortcuts = shortcuts;
      return null;
    }, [shortcuts]);

    // Bound volume keys are captured natively (Android only) and re-injected
    // into the key event pipeline
    useEffect(() {
      final keys = (keyBindings.value?.assigned ?? {})
          .where((binding) => binding.isVolumeKey)
          .map((binding) => binding.key)
          .whereType<LogicalKeyboardKey>()
          .toSet();

      if (keys.isEmpty) return null;

      setCapturedVolumeKeys(keys);
      return () => setCapturedVolumeKeys(const {});
    }, [keyBindings]);

    ref.listen(volumeKeysProvider, (previous, next) {
      next.whenData((event) {
        manager.injectKeyEvent(context, event.toKeyDownEvent());
      });
    });

    return Shortcuts.manager(
      manager: manager,
      child: Actions(
        actions: {
          NextPageIntent: CallbackAction<NextPageIntent>(
            onInvoke: (intent) => onNextPage?.call(),
          ),
          PreviousPageIntent: CallbackAction<PreviousPageIntent>(
            onInvoke: (intent) => onPreviousPage?.call(),
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
