import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/server_fonts.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/settings/select_option.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_select_option.freezed.dart';
part 'font_select_option.g.dart';

@freezed
sealed class _FontOptionData with _$FontOptionData {
  const factory _FontOptionData({
    required String? family,
    required List<String> availableFamilies,
  }) = __FontOptionData;
}

@riverpod
Future<_FontOptionData> _fontOptionData(
  Ref ref,
  int seriesId,
) async {
  final families = await ref.watch(serverFontFamiliesProvider.future);
  final setting = await ref.watch(
    epubReaderSettingsProvider(seriesId: seriesId).future,
  );
  return _FontOptionData(
    family: setting.fontFamily,
    availableFamilies: families,
  );
}

class FontSelectOption extends ConsumerWidget {
  final int seriesId;
  const new({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(_fontOptionDataProvider(seriesId));

    return Async(
      asyncValue: data,
      data: (data) {
        return SelectOption<String?>(
          icon: KoverIcons.font,
          title: l.font,
          description: l.fontDescription,
          value: data.family,
          options: [
            SelectOptionEntry(
              value: null,
              label: l.embeddedFonts,
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
