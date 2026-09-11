import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/reader/epub_reader/font_select_option_provider.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/settings/select_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class FontSelectOption extends ConsumerWidget {
  final int seriesId;
  const new({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final model = ref.watch(fontSelectOptionProvider(seriesId));

    return Async(
      asyncValue: model,
      data: (data) {
        return SelectOption<String?>(
          icon: KoverIcons.font,
          title: l.font,
          description: l.fontDescription,
          value: data.family,
          options: [
            SelectOptionEntry(
              value: null,
              label: l.defaultLabel,
            ),
            ...data.availableFamilies.map(
              (family) => SelectOptionEntry(
                value: family,
                label: family,
              ),
            ),
          ],
          onChanged: (newValue) async {
            await ref
                .read(epubReaderSettingsProvider(seriesId: seriesId).notifier)
                .setFontFamily(newValue);
          },
        );
      },
    );
  }
}
