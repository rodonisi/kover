import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/home/on_deck_scope.dart';
import 'package:kover/riverpod/managers/download_manager/download_manager.dart';
import 'package:kover/riverpod/providers/download.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/providers/want_to_read.dart';
import 'package:kover/riverpod/repository/series_repository.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/widgets/context_menu/actions_menu.dart';
import 'package:material_ui/material_ui.dart';

/// The shared series context menu (mark read, want to read, on-deck, download)
/// with an optional "Series details" entry.
class SeriesActionsContextMenu extends ConsumerWidget {
  final int seriesId;
  final VoidCallback? onViewDetails;
  final Widget child;

  const new({
    super.key,
    required this.seriesId,
    this.onViewDetails,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    final wantToRead = wantToReadProvider(seriesId: seriesId);
    final isWantToRead = ref.watch(wantToRead).value ?? false;

    final markReadProvider = markSeriesReadProvider(seriesId: seriesId);

    final downloadProgress =
        ref.watch(seriesDownloadProgressProvider(seriesId: seriesId)).value ??
        0.0;

    return ActionsContextMenu(
      onMarkRead: () async {
        await ref.read(markReadProvider.notifier).markRead();
      },
      onMarkUnread: () async {
        await ref.read(markReadProvider.notifier).markUnread();
      },
      onAddWantToRead: isWantToRead
          ? null
          : () async {
              await ref.read(wantToRead.notifier).add();
            },
      onRemoveWantToRead: isWantToRead
          ? () async {
              await ref.read(wantToRead.notifier).remove();
            }
          : null,
      onRemoveOnDeck: OnDeckScope.of(context)
          ? () async {
              await ref
                  .read(seriesRepositoryProvider)
                  .removeFromOnDeck(seriesId: seriesId);
            }
          : null,
      onDownload: downloadProgress < 1.0
          ? () async {
              await ref
                  .read(downloadManagerProvider.notifier)
                  .enqueueSeries(seriesId);
            }
          : null,
      onRemoveDownload: downloadProgress > 0.0
          ? () async {
              await ref
                  .read(downloadManagerProvider.notifier)
                  .deleteSeries(seriesId);
            }
          : null,
      extraEntries: [
        if (onViewDetails != null)
          MenuItem(
            label: Text(l.goToSeries),
            icon: const Icon(KoverIcons.series),
            onSelected: (_) => onViewDetails!(),
          ),
      ],
      child: child,
    );
  }
}
