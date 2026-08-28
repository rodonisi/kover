import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/settings/keybinds_settings.dart';

class const NextPageIntent() extends Intent;

class const PreviousPageIntent() extends Intent;

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

  const new({
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

    ref.listen(volumeKeysProvider(), (previous, next) {
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
