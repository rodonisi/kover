import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/pdf_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/safe_platform.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/settings/reader/orientation_option.dart';
import 'package:kover/widgets/settings/reader/progress_bar_option.dart';
import 'package:kover/widgets/settings/reader/read_direction_option.dart';
import 'package:kover/widgets/util/async_value.dart';

class PdfReaderSettingsBottomSheet extends ConsumerWidget {
  final int seriesId;
  const PdfReaderSettingsBottomSheet({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final pdfSettings = pdfReaderSettingsProvider(seriesId: seriesId);
    final commonSettings = commonReaderSettingsProvider(seriesId: seriesId);

    return Async(
      asyncValue: ref.watch(pdfSettings),
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
                      ChoiceOption(
                        title: l.readerMode,
                        icon: switch (settings.readerMode) {
                          PdfReaderMode.vertical => KoverIcons.verticalReader,
                          PdfReaderMode.horizontal =>
                            KoverIcons.horizontalReader,
                        },
                        value: settings.readerMode,
                        options: [
                          ChoiceOptionEntry<PdfReaderMode>(
                            value: .vertical,
                            label: l.vertical,
                            icon: KoverIcons.verticalReader,
                          ),
                          ChoiceOptionEntry<PdfReaderMode>(
                            value: .horizontal,
                            label: l.horizontal,
                            icon: KoverIcons.horizontalReader,
                          ),
                        ],
                        onChanged: (newValue) async {
                          await ref
                              .read(pdfSettings.notifier)
                              .setReaderMode(newValue);
                        },
                      ),
                      if (SafePlatform.isMobile)
                        OrientationOption(seriesId: seriesId),
                      BooleanOption(
                        title: l.ignoreSafeAreas,
                        icon: KoverIcons.safeArea,
                        value: settings.ignoreSafeAreas,
                        onChanged: (newValue) async {
                          await ref
                              .read(pdfSettings.notifier)
                              .setIgnoreSafeAreas(newValue);
                        },
                      ),
                      ProgressBarOption(seriesId: seriesId),
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
                        await ref.read(pdfSettings.notifier).setDefault();
                        await ref.read(commonSettings.notifier).setDefault();
                      },

                      icon: const Icon(KoverIcons.save),
                      label: Text(l.setDefaults),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await ref.read(pdfSettings.notifier).reset();
                        await ref.read(commonSettings.notifier).reset();
                      },
                      icon: const Icon(KoverIcons.reset),
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
