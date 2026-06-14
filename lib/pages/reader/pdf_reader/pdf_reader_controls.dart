import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/read_direction.dart';
import 'package:kover/riverpod/providers/settings/pdf_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/boolean_option.dart';
import 'package:kover/widgets/settings/choice_option.dart';
import 'package:kover/widgets/util/async_value.dart';

class PdfReaderSettingsBottomSheet extends ConsumerWidget {
  final int seriesId;
  const PdfReaderSettingsBottomSheet({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = pdfReaderSettingsProvider(seriesId: seriesId);

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
                        l.readerSettings,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ChoiceOption(
                        title: l.readingDirection,
                        icon: switch (settings.readDirection) {
                          .leftToRight => KoverIcons.readingDirectionLTR,
                          .rightToLeft => KoverIcons.readingDirectionRTL,
                        },
                        value: settings.readDirection,
                        options: [
                          ChoiceOptionEntry<ReadDirection>(
                            value: .leftToRight,
                            label: l.leftToRight,
                            icon: KoverIcons.readingDirectionLTR,
                          ),
                          ChoiceOptionEntry<ReadDirection>(
                            value: .rightToLeft,
                            label: l.rightToLeft,
                            icon: KoverIcons.readingDirectionRTL,
                          ),
                        ],
                        onChanged: (newValue) async {
                          await ref
                              .read(provider.notifier)
                              .setReadDirection(newValue);
                        },
                      ),
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
                              .read(provider.notifier)
                              .setReaderMode(newValue);
                        },
                      ),
                      BooleanOption(
                        title: l.ignoreSafeAreas,
                        icon: KoverIcons.safeArea,
                        value: settings.ignoreSafeAreas,
                        onChanged: (newValue) async {
                          await ref
                              .read(provider.notifier)
                              .setIgnoreSafeAreas(newValue);
                        },
                      ),
                      BooleanOption(
                        title: l.showProgressBar,
                        icon: KoverIcons.progressBar,
                        value: settings.showProgressBar,
                        onChanged: (newValue) async {
                          await ref
                              .read(provider.notifier)
                              .setShowProgressBar(newValue);
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
                      icon: const Icon(KoverIcons.save),
                      label: Text(l.setDefaults),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async =>
                          await ref.read(provider.notifier).reset(),
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
