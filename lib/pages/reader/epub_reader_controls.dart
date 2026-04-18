import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/pages/settings/switch_settings_entry.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EpubReaderControls extends ConsumerWidget {
  final int seriesId;
  const EpubReaderControls({super.key, required this.seriesId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(LucideIcons.slidersHorizontal),
      tooltip: 'Reader Settings',
      onPressed: () {
        showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => _ReaderSettingsBottomSheet(
            seriesId: seriesId,
          ),
        );
      },
    );
  }
}

class _ReaderSettingsBottomSheet extends ConsumerWidget {
  final int seriesId;
  const _ReaderSettingsBottomSheet({required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = epubReaderSettingsProvider(seriesId: seriesId);

    return Async(
      asyncValue: ref.watch(provider),
      data: (settings) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            left: LayoutConstants.mediumPadding,
            right: LayoutConstants.mediumPadding,
            bottom: LayoutConstants.largePadding,
          ),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            spacing: LayoutConstants.mediumPadding,
            children: [
              Text(
                'Reader Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Row(
                children: [
                  const Expanded(child: Text('Read Direction')),
                  SegmentedButton<ReadDirection>(
                    segments: const [
                      ButtonSegment<ReadDirection>(
                        value: .leftToRight,
                        label: Text('LTR'),
                        icon: Icon(LucideIcons.chevronsRight),
                      ),
                      ButtonSegment<ReadDirection>(
                        value: .rightToLeft,
                        label: Text('RTL'),
                        icon: Icon(LucideIcons.chevronsLeft),
                      ),
                    ],
                    selected: {settings.readDirection},
                    onSelectionChanged:
                        (Set<ReadDirection> newSelection) async {
                          if (newSelection.first != settings.readDirection) {
                            await ref
                                .read(provider.notifier)
                                .toggleReadDirection();
                          }
                        },
                  ),
                ],
              ),
              _SettingRow(
                label: 'Font Size',
                value: '${settings.fontSize.toInt()}',
                increaseIcon: LucideIcons.aArrowUp,
                decreaseIcon: LucideIcons.aArrowDown,
                onDecrease: settings.canDecreaseFontSize
                    ? () async =>
                          await ref.read(provider.notifier).decreaseFontSize()
                    : null,
                onIncrease: settings.canIncreaseFontSize
                    ? () async =>
                          await ref.read(provider.notifier).increaseFontSize()
                    : null,
              ),
              _SettingRow(
                label: 'Margins',
                value: '${settings.marginSize.toInt()}',
                increaseIcon: LucideIcons.arrowRightFromLine,
                decreaseIcon: LucideIcons.arrowLeftToLine,
                onDecrease: settings.canDecreaseMarginSize
                    ? () async =>
                          await ref.read(provider.notifier).decreaseMarginSize()
                    : null,
                onIncrease: settings.canIncreaseMarginSize
                    ? () async =>
                          await ref.read(provider.notifier).increaseMarginSize()
                    : null,
              ),
              _SettingRow(
                label: 'Line Height',
                value: settings.lineHeight.toStringAsFixed(1),
                increaseIcon: LucideIcons.listChevronsUpDown,
                decreaseIcon: LucideIcons.listChevronsDownUp,
                onDecrease: settings.canDecreaseLineHeight
                    ? () async =>
                          await ref.read(provider.notifier).decreaseLineHeight()
                    : null,
                onIncrease: settings.canIncreaseLineHeight
                    ? () async =>
                          await ref.read(provider.notifier).increaseLineHeight()
                    : null,
              ),
              SwitchSettingsEntry(
                title: 'Highlight resume point',
                value: settings.highlightResumePoint,
                onChanged: (value) async {
                  await ref
                      .read(provider.notifier)
                      .setHighlightResumePoint(value);
                },
              ),
              Row(
                spacing: LayoutConstants.mediumPadding,
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async =>
                          await ref.read(provider.notifier).setDefault(),
                      icon: const Icon(LucideIcons.save),
                      label: const Text('Use as Defaults'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async =>
                          await ref.read(provider.notifier).reset(),
                      icon: const Icon(LucideIcons.rotateCcw),
                      label: const Text('Reset to Defaults'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    required this.increaseIcon,
    required this.decreaseIcon,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String value;
  final IconData increaseIcon;
  final IconData decreaseIcon;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(label),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onDecrease,
          icon: Icon(decreaseIcon),
        ),
        const SizedBox(width: LayoutConstants.smallPadding),
        IconButton.filledTonal(
          onPressed: onIncrease,
          icon: Icon(increaseIcon),
        ),
      ],
    );
  }
}
