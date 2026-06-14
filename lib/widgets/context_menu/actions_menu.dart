import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/utils/extensions/iterable.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ActionsContextMenu extends StatelessWidget {
  final VoidCallback? onMarkRead;
  final VoidCallback? onMarkUnread;
  final VoidCallback? onAddWantToRead;
  final VoidCallback? onRemoveWantToRead;
  final VoidCallback? onDownload;
  final VoidCallback? onRemoveDownload;
  final VoidCallback? onRefreshMetadata;
  final VoidCallback? onRefreshCovers;
  final Widget child;

  const ActionsContextMenu({
    super.key,
    this.onMarkRead,
    this.onMarkUnread,
    this.onAddWantToRead,
    this.onRemoveWantToRead,
    this.onDownload,
    this.onRemoveDownload,
    this.onRefreshMetadata,
    this.onRefreshCovers,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _LocalContextMenuRegion(
      contextMenu: _getContextMenu(
        context: context,
        onMarkRead: onMarkRead,
        onMarkUnread: onMarkUnread,
        onAddWantToRead: onAddWantToRead,
        onRemoveWantToRead: onRemoveWantToRead,
        onDownload: onDownload,
        onRemoveDownload: onRemoveDownload,
        onRefreshMetadata: onRefreshMetadata,
        onRefreshCovers: onRefreshCovers,
      ),
      child: child,
    );
  }
}

class ActionsMenuButton extends StatelessWidget {
  final void Function()? onMarkRead;
  final void Function()? onMarkUnread;
  final void Function()? onDownload;
  final void Function()? onRemoveDownload;
  final void Function()? onRefreshMetadata;
  final VoidCallback? onRefreshCovers;
  final Widget child;

  const ActionsMenuButton({
    super.key,
    this.onMarkRead,
    this.onMarkUnread,
    this.onDownload,
    this.onRemoveDownload,
    this.onRefreshMetadata,
    this.onRefreshCovers,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenuButton(
      menu: _getContextMenu(
        context: context,
        onMarkRead: onMarkRead,
        onMarkUnread: onMarkUnread,
        onDownload: onDownload,
        onRemoveDownload: onRemoveDownload,
        onRefreshMetadata: onRefreshMetadata,
        onRefreshCovers: onRefreshCovers,
      ),
      icon: child,
    );
  }
}

class _LocalContextMenuRegion extends StatelessWidget {
  const _LocalContextMenuRegion({
    required this.contextMenu,
    required this.child,
  });

  final ContextMenu contextMenu;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ContextMenuRegion(
      contextMenu: contextMenu,
      child: child,
    );
  }
}

ContextMenu _getContextMenu({
  required BuildContext context,
  VoidCallback? onMarkRead,
  VoidCallback? onMarkUnread,
  VoidCallback? onAddWantToRead,
  VoidCallback? onRemoveWantToRead,
  VoidCallback? onDownload,
  VoidCallback? onRemoveDownload,
  VoidCallback? onRefreshMetadata,
  VoidCallback? onRefreshCovers,
}) {
  final wantToReadEntries = _wantToReadEntries(
    context: context,
    onAddWantToRead: onAddWantToRead,
    onRemoveWantToRead: onRemoveWantToRead,
  );
  final markReadEntries = _markReadEntries(
    context: context,
    onMarkRead: onMarkRead,
    onMarkUnread: onMarkUnread,
  );
  final downloadEntries = _downloadEntries(
    context: context,
    onDownload: onDownload,
    onRemoveDownload: onRemoveDownload,
  );
  final refreshEntries = _refreshEntries(
    context: context,
    onRefreshMetadata: onRefreshMetadata,
    onRefreshCovers: onRefreshCovers,
  );
  return ContextMenu(
    entries: _withDividers(
      [
        wantToReadEntries,
        markReadEntries,
        downloadEntries,
        refreshEntries,
      ],
    ),
  );
}

List<ContextMenuEntry> _withDividers(List<List<ContextMenuEntry>> entries) {
  final nonEmptyEntries = entries.where((e) => e.isNotEmpty).toList();
  return nonEmptyEntries
      .interleave([const MenuDivider()])
      .expand((e) => e)
      .toList();
}

List<ContextMenuEntry> _wantToReadEntries({
  required BuildContext context,
  void Function()? onAddWantToRead,
  void Function()? onRemoveWantToRead,
}) {
  final l = AppLocalizations.of(context);
  return [
    if (onAddWantToRead != null)
      MenuItem(
        label: Text(l.addToWantToRead),
        icon: const Icon(LucideIcons.star),
        onSelected: (_) => onAddWantToRead(),
      ),
    if (onRemoveWantToRead != null)
      MenuItem(
        label: Text(l.removeFromWantToRead),
        icon: const Icon(LucideIcons.starOff),
        onSelected: (_) => onRemoveWantToRead(),
      ),
  ];
}

List<ContextMenuEntry> _markReadEntries({
  required BuildContext context,
  void Function()? onMarkRead,
  void Function()? onMarkUnread,
}) {
  final l = AppLocalizations.of(context);
  return [
    if (onMarkRead != null)
      MenuItem(
        label: Text(l.markAsRead),
        icon: const Icon(LucideIcons.bookCheck),
        onSelected: (_) => onMarkRead(),
      ),
    if (onMarkUnread != null)
      MenuItem(
        label: Text(l.markAsUnread),
        icon: const Icon(LucideIcons.bookX),
        onSelected: (_) => onMarkUnread(),
      ),
  ];
}

List<ContextMenuEntry> _downloadEntries({
  required BuildContext context,
  void Function()? onDownload,
  void Function()? onRemoveDownload,
}) {
  final l = AppLocalizations.of(context);
  return [
    if (onDownload != null)
      MenuItem(
        label: Text(l.download),
        icon: const Icon(LucideIcons.download),
        onSelected: (_) => onDownload(),
      ),
    if (onRemoveDownload != null)
      MenuItem(
        label: Text(l.removeDownload),
        icon: const Icon(LucideIcons.trash2),
        onSelected: (_) => onRemoveDownload(),
      ),
  ];
}

List<ContextMenuEntry> _refreshEntries({
  required BuildContext context,
  VoidCallback? onRefreshMetadata,
  VoidCallback? onRefreshCovers,
}) {
  final l = AppLocalizations.of(context);
  return [
    if (onRefreshMetadata != null)
      MenuItem(
        label: Text(l.refreshMetadata),
        icon: const Icon(LucideIcons.fileBracesCorner),
        onSelected: (_) => onRefreshMetadata(),
      ),
    if (onRefreshCovers != null)
      MenuItem(
        label: Text(l.refreshCovers),
        icon: const Icon(LucideIcons.imageDown),
        onSelected: (_) => onRefreshCovers(),
      ),
  ];
}
