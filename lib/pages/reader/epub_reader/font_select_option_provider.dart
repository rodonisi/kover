import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/riverpod/providers/server_fonts.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_select_option_provider.freezed.dart';
part 'font_select_option_provider.g.dart';

@freezed
class FontSelectOptionModel({
  required final String? family,
  required final List<String> availableFamilies,
}) with _$FontSelectOptionModel;

@riverpod
Future<FontSelectOptionModel> fontSelectOption(
  Ref ref,
  int seriesId,
) async {
  final families = await ref.watch(serverFontFamiliesProvider.future);
  final setting = await ref.watch(
    epubReaderSettingsProvider(seriesId: seriesId).future,
  );

  return FontSelectOptionModel(
    family: setting.fontFamily,
    availableFamilies: families,
  );
}
