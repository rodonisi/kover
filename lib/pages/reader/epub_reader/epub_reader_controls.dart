import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/settings/numeric_option.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EpubReaderSettingsBottomSheet extends ConsumerWidget {
  final int seriesId;
  const EpubReaderSettingsBottomSheet({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = epubReaderSettingsProvider(seriesId: seriesId);

    return Async(
      asyncValue: ref.watch(provider),
      data: (settings) {
        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: LayoutConstants.largePadding,
                    right: LayoutConstants.largePadding,
                    bottom: LayoutConstants.largePadding,
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: LayoutConstants.largePadding,
                    children: [
                      Text(
                        'Reader Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ChoiceOption(
                        title: 'Reading Direction',
                        icon: settings.readDirection == .leftToRight
                            ? LucideIcons.chevronsRight
                            : LucideIcons.chevronsLeft,
                        value: settings.readDirection,
                        options: const [
                          ChoiceOptionEntry<ReadDirection>(
                            value: ReadDirection.leftToRight,
                            label: 'Left To Right',
                            icon: LucideIcons.chevronsRight,
                          ),
                          ChoiceOptionEntry<ReadDirection>(
                            value: ReadDirection.rightToLeft,
                            label: 'Right To Left',
                            icon: LucideIcons.chevronsLeft,
                          ),
                        ],
                        onChanged: (newValue) async {
                          if (newValue != settings.readDirection) {
                            await ref
                                .read(provider.notifier)
                                .toggleReadDirection();
                          }
                        },
                      ),
                      NumericOption(
                        title: 'Font Size',
                        icon: LucideIcons.aLargeSmallDir,
                        value: settings.fontSize,
                        min: EpubReaderSettingsLimits.fontSizeMin,
                        max: EpubReaderSettingsLimits.fontSizeMax,
                        step: EpubReaderSettingsLimits.fontSizeStep,
                        decimalPlaces: 0,
                        onChanged: (newValue) async => await ref
                            .read(provider.notifier)
                            .setFontSize(newValue),
                      ),
                      NumericOption(
                        title: 'Margins',
                        icon: LucideIcons.panelLeftDashed,
                        value: settings.marginSize,
                        min: EpubReaderSettingsLimits.marginSizeMin,
                        max: EpubReaderSettingsLimits.marginSizeMax,
                        step: EpubReaderSettingsLimits.marginSizeStep,
                        decimalPlaces: 0,
                        onChanged: (newValue) async => await ref
                            .read(provider.notifier)
                            .setMarginSize(newValue),
                      ),

                      NumericOption(
                        title: 'Line Height',
                        icon: LucideIcons.listChevronsUpDown,
                        value: settings.lineHeight,
                        min: EpubReaderSettingsLimits.lineHeightMin,
                        max: EpubReaderSettingsLimits.lineHeightMax,
                        step: EpubReaderSettingsLimits.lineHeightStep,
                        onChanged: (newValue) async => await ref
                            .read(provider.notifier)
                            .setLineHeight(newValue),
                      ),
                      NumericOption(
                        value: settings.wordSpacing,
                        title: 'Word Spacing',
                        min: EpubReaderSettingsLimits.wordSpacingMin,
                        max: EpubReaderSettingsLimits.wordSpacingMax,
                        step: EpubReaderSettingsLimits.wordSpacingStep,
                        onChanged: (newValue) async => await ref
                            .read(provider.notifier)
                            .setWordSpacing(newValue),
                        icon: LucideIcons.listMinus,
                      ),
                      NumericOption(
                        title: 'Letter Spacing',
                        icon: LucideIcons.wholeWord,
                        value: settings.letterSpacing,
                        min: EpubReaderSettingsLimits.letterSpacingMin,
                        max: EpubReaderSettingsLimits.letterSpacingMax,
                        step: EpubReaderSettingsLimits.letterSpacingStep,
                        onChanged: (newValue) async => await ref
                            .read(provider.notifier)
                            .setLetterSpacing(newValue),
                      ),
                      BooleanOption(
                        icon: LucideIcons.highlighter,
                        title: 'Highlight Resume Paragraph',
                        value: settings.highlightResumePoint,
                        onChanged: (value) async {
                          await ref
                              .read(provider.notifier)
                              .setHighlightResumePoint(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(
                left: LayoutConstants.largePadding,
                right: LayoutConstants.largePadding,
                bottom: LayoutConstants.largePadding,
                top: LayoutConstants.mediumPadding,
              ),
              child: Row(
                spacing: LayoutConstants.mediumPadding,
                crossAxisAlignment: .center,
                mainAxisAlignment: .center,
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async =>
                          await ref.read(provider.notifier).setDefault(),
                      icon: const Icon(LucideIcons.save),
                      label: const Text('Set Defaults'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async =>
                          await ref.read(provider.notifier).reset(),
                      icon: const Icon(LucideIcons.rotateCcw),
                      label: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
