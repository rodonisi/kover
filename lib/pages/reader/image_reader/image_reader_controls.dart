import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/providers/breakpoints.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/settings/numeric_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ImageReaderSettingsBottomSheet extends ConsumerWidget {
  final int seriesId;

  const ImageReaderSettingsBottomSheet({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = imageReaderSettingsProvider(seriesId: seriesId);
    final breakpoint = ref.watch(breakpointsProvider);

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
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    spacing: LayoutConstants.largePadding,
                    children: [
                      Text(
                        l.readerSettings,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ChoiceOption<ReadDirection>(
                        title: l.readingDirection,
                        icon: settings.readDirection == .leftToRight
                            ? LucideIcons.chevronsRight
                            : LucideIcons.chevronsLeft,
                        options: [
                          ChoiceOptionEntry(
                            value: .leftToRight,
                            label: l.leftToRight,
                            icon: LucideIcons.chevronsRight,
                          ),
                          ChoiceOptionEntry(
                            value: .rightToLeft,
                            label: l.rightToLeft,
                            icon: LucideIcons.chevronsLeft,
                          ),
                        ],
                        value: settings.readDirection,
                        onChanged: (newValue) async {
                          await ref
                              .read(provider.notifier)
                              .setReadDirection(newValue);
                        },
                      ),
                      ChoiceOption<ReaderMode>(
                        title: l.readerMode,
                        icon: switch (settings.readerMode) {
                          .horizontal => LucideIcons.moveHorizontal,
                          .vertical => LucideIcons.moveVertical,
                          .spread => LucideIcons.columns2,
                        },
                        options: [
                          ChoiceOptionEntry(
                            value: .horizontal,
                            label: l.horizontal,
                            icon: LucideIcons.moveHorizontal,
                          ),
                          ChoiceOptionEntry(
                            value: .vertical,
                            label: l.vertical,
                            icon: LucideIcons.moveVertical,
                          ),
                          if (breakpoint != .compact)
                            ChoiceOptionEntry(
                              value: .spread,
                              label: l.twoPage,
                              icon: LucideIcons.columns2,
                            ),
                        ],
                        value: settings.readerMode,
                        onChanged: (newValue) async {
                          await ref
                              .read(provider.notifier)
                              .setReaderMode(newValue);
                        },
                      ),
                      if (settings.readerMode == .horizontal) ...[
                        ChoiceOption<ImageScaleType>(
                          title: l.fitDirection,
                          icon: switch (settings.scaleType) {
                            .fitWidth => KoverIcons.fitWidth,
                            .fitHeight => KoverIcons.fitHeight,
                            .contain => KoverIcons.fitContain,
                          },
                          options: [
                            ChoiceOptionEntry(
                              value: .contain,
                              label: l.contain,
                              icon: KoverIcons.fitContain,
                            ),
                            ChoiceOptionEntry(
                              value: .fitWidth,
                              label: l.width,
                              icon: KoverIcons.fitWidth,
                            ),
                            ChoiceOptionEntry(
                              value: .fitHeight,
                              label: l.height,
                              icon: KoverIcons.fitHeight,
                            ),
                          ],
                          value: settings.scaleType,
                          onChanged: (newValue) async {
                            if (newValue != settings.scaleType) {
                              await ref
                                  .read(provider.notifier)
                                  .setScaleType(newValue);
                            }
                          },
                        ),
                      ],
                      if (settings.readerMode == .vertical) ...[
                        NumericOption(
                          title: l.margins,
                          icon: LucideIcons.panelLeftDashed,
                          value: settings.verticalReaderPadding,
                          min: ImageReaderSettingsLimits
                              .verticalReaderPaddingMin,
                          max: ImageReaderSettingsLimits
                              .verticalReaderPaddingMax,
                          step: ImageReaderSettingsLimits
                              .verticalReaderPaddingStep,
                          onChanged: (newValue) async => await ref
                              .read(provider.notifier)
                              .setVerticalReaderPadding(newValue),
                        ),
                        NumericOption(
                          title: l.verticalGap,
                          icon: LucideIcons.unfoldVertical,
                          value: settings.verticalReaderGap,
                          min: ImageReaderSettingsLimits.verticalReaderGapMin,
                          max: ImageReaderSettingsLimits.verticalReaderGapMax,
                          step: ImageReaderSettingsLimits.verticalReaderGapStep,
                          onChanged: (newValue) async => await ref
                              .read(provider.notifier)
                              .setVerticalReaderGap(newValue),
                        ),
                      ],
                      if (settings.readerMode == .spread) ...[
                        NumericOption(
                          title: l.pageGap,
                          icon: LucideIcons.unfoldHorizontal,
                          value: settings.spreadReaderGap,
                          min: ImageReaderSettingsLimits.spreadReaderGapMin,
                          max: ImageReaderSettingsLimits.spreadReaderGapMax,
                          step: ImageReaderSettingsLimits.spreadReaderGapStep,
                          decimalPlaces: 0,
                          onChanged: (newValue) async => await ref
                              .read(provider.notifier)
                              .setSpreadReaderGap(newValue),
                        ),
                        BooleanOption(
                          title: l.coverPage,
                          description: l.coverPageDescription,
                          icon: LucideIcons.bookImage,
                          value: settings.spreadCoverPage,
                          onChanged: (newValue) async => await ref
                              .read(provider.notifier)
                              .setSpreadCoverPage(newValue),
                        ),
                      ],
                      BooleanOption(
                        title: l.ignoreSafeAreas,
                        icon: KoverIcons.safeArea,
                        value: settings.ignoreSafeAreas,
                        onChanged: (newValue) async => await ref
                            .read(provider.notifier)
                            .setIgnoreSafeAreas(newValue),
                      ),
                      BooleanOption(
                        title: l.showProgressBar,
                        icon: KoverIcons.progressBar,
                        value: settings.showProgressBar,
                        onChanged: (newValue) async => await ref
                            .read(provider.notifier)
                            .setShowProgressBar(newValue),
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
                      label: Text(l.setDefaults),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async =>
                          await ref.read(provider.notifier).reset(),
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
