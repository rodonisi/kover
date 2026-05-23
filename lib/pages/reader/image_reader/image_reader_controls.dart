import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
                        'Reader Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ChoiceOption<ReadDirection>(
                        title: 'Reading Direction',
                        icon: settings.readDirection == .leftToRight
                            ? LucideIcons.chevronsRight
                            : LucideIcons.chevronsLeft,
                        options: const [
                          ChoiceOptionEntry(
                            value: .leftToRight,
                            label: 'Left to Right',
                            icon: LucideIcons.chevronsRight,
                          ),
                          ChoiceOptionEntry(
                            value: .rightToLeft,
                            label: 'Right to Left',
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
                        title: 'Reader Mode',
                        icon: switch (settings.readerMode) {
                          .horizontal => LucideIcons.moveHorizontal,
                          .vertical => LucideIcons.moveVertical,
                          .spread => LucideIcons.columns2,
                        },
                        options: [
                          const ChoiceOptionEntry(
                            value: .horizontal,
                            label: 'Horizontal',
                            icon: LucideIcons.moveHorizontal,
                          ),
                          const ChoiceOptionEntry(
                            value: .vertical,
                            label: 'Vertical',
                            icon: LucideIcons.moveVertical,
                          ),
                          if (breakpoint != .compact)
                            const ChoiceOptionEntry(
                              value: .spread,
                              label: 'Two Page',
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
                          title: 'Fit Direction',
                          icon: switch (settings.scaleType) {
                            .fitWidth => KoverIcons.fitWidth,
                            .fitHeight => KoverIcons.fitHeight,
                            .contain => KoverIcons.fitContain,
                          },
                          options: const [
                            ChoiceOptionEntry(
                              value: .contain,
                              label: 'Contain',
                              icon: KoverIcons.fitContain,
                            ),
                            ChoiceOptionEntry(
                              value: .fitWidth,
                              label: 'Width',
                              icon: KoverIcons.fitWidth,
                            ),
                            ChoiceOptionEntry(
                              value: .fitHeight,
                              label: 'Height',
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
                          title: 'Margins',
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
                          title: 'Vertical Gap',
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
                          title: 'Page Gap',
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
                          title: 'Cover Page',
                          description:
                              'Treat the first page as the cover, showing it as a single page',
                          icon: LucideIcons.bookImage,
                          value: settings.spreadCoverPage,
                          onChanged: (newValue) async => await ref
                              .read(provider.notifier)
                              .setSpreadCoverPage(newValue),
                        ),
                      ],
                      BooleanOption(
                        title: 'Ignore Safe Areas',
                        icon: KoverIcons.safeArea,
                        value: settings.ignoreSafeAreas,
                        onChanged: (newValue) async => await ref
                            .read(provider.notifier)
                            .setIgnoreSafeAreas(newValue),
                      ),
                      BooleanOption(
                        title: 'Show Progress Bar',
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
