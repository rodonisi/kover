import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/safe_platform.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/numeric_option.dart';
import 'package:kover/widgets/settings/reader/navigation_gestures_option.dart';
import 'package:kover/widgets/settings/reader/orientation_option.dart';
import 'package:kover/widgets/settings/reader/progress_bar_option.dart';
import 'package:kover/widgets/settings/reader/read_direction_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EpubReaderSettingsBottomSheet extends ConsumerWidget {
  final int seriesId;
  const EpubReaderSettingsBottomSheet({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final epubSettings = epubReaderSettingsProvider(seriesId: seriesId);
    final commonSettings = commonReaderSettingsProvider(seriesId: seriesId);

    return Async(
      asyncValue: ref.watch(epubSettings),
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
                        l.readerSettings,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ReadDirectionOption(seriesId: seriesId),
                      NumericOption(
                        title: l.fontSize,
                        icon: LucideIcons.aLargeSmallDir,
                        value: settings.fontSize,
                        min: EpubReaderSettingsLimits.fontSizeMin,
                        max: EpubReaderSettingsLimits.fontSizeMax,
                        step: EpubReaderSettingsLimits.fontSizeStep,
                        decimalPlaces: 0,
                        onChanged: (newValue) async => await ref
                            .read(epubSettings.notifier)
                            .setFontSize(newValue),
                      ),
                      NumericOption(
                        title: l.margins,
                        icon: LucideIcons.panelLeftDashed,
                        value: settings.marginSize,
                        min: EpubReaderSettingsLimits.marginSizeMin,
                        max: EpubReaderSettingsLimits.marginSizeMax,
                        step: EpubReaderSettingsLimits.marginSizeStep,
                        decimalPlaces: 0,
                        onChanged: (newValue) async => await ref
                            .read(epubSettings.notifier)
                            .setMarginSize(newValue),
                      ),

                      NumericOption(
                        title: l.lineHeight,
                        icon: LucideIcons.listChevronsUpDown,
                        value: settings.lineHeight,
                        min: EpubReaderSettingsLimits.lineHeightMin,
                        max: EpubReaderSettingsLimits.lineHeightMax,
                        step: EpubReaderSettingsLimits.lineHeightStep,
                        onChanged: (newValue) async => await ref
                            .read(epubSettings.notifier)
                            .setLineHeight(newValue),
                      ),
                      NumericOption(
                        value: settings.wordSpacing,
                        title: l.wordSpacing,
                        min: EpubReaderSettingsLimits.wordSpacingMin,
                        max: EpubReaderSettingsLimits.wordSpacingMax,
                        step: EpubReaderSettingsLimits.wordSpacingStep,
                        onChanged: (newValue) async => await ref
                            .read(epubSettings.notifier)
                            .setWordSpacing(newValue),
                        icon: LucideIcons.listMinus,
                      ),
                      NumericOption(
                        title: l.letterSpacing,
                        icon: LucideIcons.wholeWord,
                        value: settings.letterSpacing,
                        min: EpubReaderSettingsLimits.letterSpacingMin,
                        max: EpubReaderSettingsLimits.letterSpacingMax,
                        step: EpubReaderSettingsLimits.letterSpacingStep,
                        onChanged: (newValue) async => await ref
                            .read(epubSettings.notifier)
                            .setLetterSpacing(newValue),
                      ),
                      if (SafePlatform.isMobile)
                        OrientationOption(seriesId: seriesId),
                      BooleanOption(
                        icon: LucideIcons.highlighter,
                        title: l.highlightResumeParagraph,
                        value: settings.highlightResumePoint,
                        onChanged: (value) async {
                          await ref
                              .read(epubSettings.notifier)
                              .setHighlightResumePoint(value);
                        },
                      ),
                      ProgressBarOption(seriesId: seriesId),
                      NavigationGesturesOption(seriesId: seriesId),
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
                      onPressed: () async {
                        await ref.read(epubSettings.notifier).setDefault();
                        await ref.read(commonSettings.notifier).setDefault();
                      },
                      icon: const Icon(LucideIcons.save),
                      label: Text(l.setDefaults),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await ref.read(epubSettings.notifier).reset();
                        await ref.read(commonSettings.notifier).reset();
                      },
                      icon: const Icon(LucideIcons.rotateCcw),
                      label: Text(l.reset),
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
