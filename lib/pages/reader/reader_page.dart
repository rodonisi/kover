import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/reader/epub_reader/epub_reader.dart';
import 'package:kover/pages/reader/image_reader/image_reader.dart';
import 'package:kover/pages/reader/pdf_reader/pdf_reader.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ReaderPage extends HookConsumerWidget {
  final int seriesId;
  final int? chapterId;
  final int? readingListId;

  const ReaderPage({
    super.key,
    required this.seriesId,
    this.chapterId,
    this.readingListId,
  });

  Future<void> _exitImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(
      .manual,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    useEffect(() {
      SystemChrome.setEnabledSystemUIMode(.immersiveSticky);

      return () {
        _exitImmersiveMode();
      };
    }, const []);

    final provider = readerProvider(
      seriesId: seriesId,
      chapterId: chapterId,
      readingListId: readingListId,
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;

        Future.microtask(
          () {
            _exitImmersiveMode();
            ref.read(syncManagerProvider.notifier).syncProgress();
          },
        );
      },
      child: Async(
        asyncValue: ref.watch(provider),
        data: (data) {
          return switch (data.series.format) {
            .archive || .image => ImageReader(
              seriesId: data.series.id,
              chapterId: data.chapter.id,
              readingListId: data.readingListId,
            ),
            .epub => EpubReader(
              seriesId: data.series.id,
              chapterId: data.chapter.id,
              readingListId: data.readingListId,
            ),
            .pdf => PdfReader(
              seriesId: data.series.id,
              chapterId: data.chapter.id,
              readingListId: data.readingListId,
            ),
            _ => Center(
              child: Column(
                mainAxisAlignment: .center,
                crossAxisAlignment: .center,
                spacing: LayoutConstants.mediumPadding,
                children: [
                  Icon(
                    LucideIcons.circleX,
                    size: LayoutConstants.largeIcon,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  Text(
                    l.unsupportedFormat(data.series.format.name.toUpperCase()),
                  ),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: Text(l.back),
                  ),
                ],
              ),
            ),
          };
        },
      ),
    );
  }
}
