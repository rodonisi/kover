import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/extensions/epub_theme.dart';

class EpubThemeOverride extends ConsumerWidget {
  final int seriesId;
  final Widget child;

  const EpubThemeOverride({
    super.key,
    required this.seriesId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(
      epubReaderSettingsProvider(seriesId: seriesId).select(
        (value) => value.whenOrNull(data: (data) => data.theme),
      ),
    );
    return Theme(
      data: theme?.data ?? Theme.of(context),
      child: Scaffold(
        body: child,
      ),
    );
  }
}
