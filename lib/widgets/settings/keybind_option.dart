import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/keybinds_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/settings/option_container.dart';
import 'package:material_ui/material_ui.dart';

class KeybindOption extends ConsumerWidget {
  final String title;
  final IconData? icon;
  final ReaderKeyBinding value;
  final ReaderKeyBinding defaultValue;
  final void Function(ReaderKeyBinding value)? onChanged;

  const new({
    super.key,
    required this.title,
    required this.value,
    required this.defaultValue,
    this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OptionContainer(
      title: title,
      icon: icon,
      sameRow: true,
      child: OutlinedButton.icon(
        icon: const Icon(KoverIcons.keyboard),
        label: _KeyBindingLabel(binding: value),
        onPressed: () async {
          final result = await showDialog<ReaderKeyBinding>(
            context: context,
            builder: (context) => _KeybindCaptureDialog(
              title: title,
              currentValue: value,
              defaultValue: defaultValue,
            ),
          );

          if (result != null) {
            onChanged?.call(result);
          }
        },
      ),
    );
  }
}

class _KeyBindingLabel extends StatelessWidget {
  final ReaderKeyBinding binding;

  const new({required this.binding});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final materialL = MaterialLocalizations.of(context);

    final keyLabel = switch (binding.key) {
      LogicalKeyboardKey.audioVolumeUp => l.keybindVolumeUp,
      LogicalKeyboardKey.audioVolumeDown => l.keybindVolumeDown,
      LogicalKeyboardKey.arrowLeft => '←',
      LogicalKeyboardKey.arrowRight => '→',
      LogicalKeyboardKey.arrowUp => '↑',
      LogicalKeyboardKey.arrowDown => '↓',
      _ => binding.keyLabel,
    };

    return Text(
      [
        if (binding.control) materialL.keyboardKeyControl,
        if (binding.alt) materialL.keyboardKeyAlt,
        if (binding.shift) materialL.keyboardKeyShift,
        if (binding.meta) materialL.keyboardKeyMeta,
        keyLabel,
      ].join(' + '),
    );
  }
}

class _KeybindCaptureDialog extends HookConsumerWidget {
  static final _controlKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
  };
  static final _altKeys = {
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  };
  static final _shiftKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  };
  static final _metaKeys = {
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };
  static final _modifierKeys = {
    ..._controlKeys,
    ..._altKeys,
    ..._shiftKeys,
    ..._metaKeys,
  };

  final String title;
  final ReaderKeyBinding currentValue;
  final ReaderKeyBinding defaultValue;

  const new({
    required this.title,
    required this.currentValue,
    required this.defaultValue,
  });

  static bool _anyPressed(Set pressed, Set keys) => keys.any(pressed.contains);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final captured = useState<ReaderKeyBinding?>(null);
    final pending = captured.value;

    ref.listen(volumeKeysProvider(capturedKeys: capturableVolumeKeys), (
      previous,
      next,
    ) {
      next.whenData((event) {
        captured.value = ReaderKeyBinding(
          id: event.key.keyId,
          keyLabel: event.key.keyLabel,
        );
      });
    });

    final assigned =
        ref.watch(keybindsSettingsProvider).value?.assigned ??
        const <ReaderKeyBinding>{};

    final conflicts =
        pending != null &&
        assigned.any(
          (binding) => binding != currentValue && binding == pending,
        );

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: LayoutConstants.smallPadding,
        children: [
          Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return .ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                return .ignored;
              }
              if (_modifierKeys.contains(event.logicalKey)) return .handled;

              log.debug(
                'Keybind capture',
                attributes: {'key': event.logicalKey},
              );

              final pressed = HardwareKeyboard.instance.logicalKeysPressed;
              captured.value = ReaderKeyBinding(
                id: event.logicalKey.keyId,
                keyLabel: event.logicalKey.keyLabel,
                control: _anyPressed(pressed, _controlKeys),
                alt: _anyPressed(pressed, _altKeys),
                shift: _anyPressed(pressed, _shiftKeys),
                meta: _anyPressed(pressed, _metaKeys),
              );

              return .handled;
            },
            child: Container(
              width: double.infinity,
              padding: const .symmetric(
                horizontal: LayoutConstants.mediumPadding,
                vertical: LayoutConstants.smallPadding,
              ),
              decoration: BoxDecoration(
                border: .all(
                  color: theme.colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(
                  LayoutConstants.smallerBorderRadius,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: pending == null
                        ? Text(
                            l.keybindPressAKey,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor,
                            ),
                          )
                        : _KeyBindingLabel(
                            binding: pending,
                          ),
                  ),
                  const Icon(KoverIcons.keyboard),
                ],
              ),
            ),
          ),
          if (conflicts)
            Text(
              l.keybindAlreadyAssigned,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(defaultValue),
          icon: const Icon(KoverIcons.reset),
          label: Text(l.reset),
        ),
        FilledButton(
          onPressed: pending == null || conflicts
              ? null
              : () => Navigator.of(context).pop(pending),
          child: Text(l.save),
        ),
      ],
    );
  }
}
