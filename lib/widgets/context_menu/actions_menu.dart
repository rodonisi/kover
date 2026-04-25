import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:kover/widgets/context_menu/context_menu_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ActionsContextMenu extends StatelessWidget {
  final void Function()? onMarkRead;
  final void Function()? onMarkUnread;
  final void Function()? onAddWantToRead;
  final void Function()? onRemoveWantToRead;
  final void Function()? onDownload;
  final void Function()? onRemoveDownload;
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
    this.onRefreshCovers,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _LocalContextMenuRegion(
      contextMenu: _getContextMenu(
        onMarkRead: onMarkRead,
        onMarkUnread: onMarkUnread,
        onAddWantToRead: onAddWantToRead,
        onRemoveWantToRead: onRemoveWantToRead,
        onDownload: onDownload,
        onRemoveDownload: onRemoveDownload,
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
  final VoidCallback? onRefreshCovers;
  final Widget child;

  const ActionsMenuButton({
    super.key,
    this.onMarkRead,
    this.onMarkUnread,
    this.onDownload,
    this.onRemoveDownload,
    this.onRefreshCovers,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenuButton(
      menu: _getContextMenu(
        onMarkRead: onMarkRead,
        onMarkUnread: onMarkUnread,
        onDownload: onDownload,
        onRemoveDownload: onRemoveDownload,
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
  VoidCallback? onMarkRead,
  VoidCallback? onMarkUnread,
  VoidCallback? onAddWantToRead,
  VoidCallback? onRemoveWantToRead,
  VoidCallback? onDownload,
  VoidCallback? onRemoveDownload,
  VoidCallback? onRefreshCovers,
}) {
  final wantToReadEntries = _wantToReadEntries(
    onAddWantToRead: onAddWantToRead,
    onRemoveWantToRead: onRemoveWantToRead,
  );
  final markReadEntries = _markReadEntries(
    onMarkRead: onMarkRead,
    onMarkUnread: onMarkUnread,
  );
  final downloadEntries = _downloadEntries(
    onDownload: onDownload,
    onRemoveDownload: onRemoveDownload,
  );
  final refreshEntries = _refreshEntries(
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
  final result = <ContextMenuEntry>[];
  for (var i = 0; i < nonEmptyEntries.length; i++) {
    result.addAll(nonEmptyEntries[i]);
    if (i < nonEmptyEntries.length - 1) {
      result.add(const MenuDivider());
    }
  }
  return result;
}

List<ContextMenuEntry> _wantToReadEntries({
  void Function()? onAddWantToRead,
  void Function()? onRemoveWantToRead,
}) {
  return [
    if (onAddWantToRead != null)
      MenuItem(
        label: const Text('Add to Want to Read'),
        icon: const Icon(LucideIcons.star),
        onSelected: (_) => onAddWantToRead(),
      ),
    if (onRemoveWantToRead != null)
      MenuItem(
        label: const Text('Remove from Want to Read'),
        icon: const Icon(LucideIcons.starOff),
        onSelected: (_) => onRemoveWantToRead(),
      ),
  ];
}

List<ContextMenuEntry> _markReadEntries({
  void Function()? onMarkRead,
  void Function()? onMarkUnread,
}) {
  return [
    if (onMarkRead != null)
      MenuItem(
        label: const Text('Mark Read'),
        icon: const Icon(LucideIcons.bookCheck),
        onSelected: (_) => onMarkRead(),
      ),
    if (onMarkUnread != null)
      MenuItem(
        label: const Text('Mark Unread'),
        icon: const Icon(LucideIcons.bookX),
        onSelected: (_) => onMarkUnread(),
      ),
  ];
}

List<ContextMenuEntry> _downloadEntries({
  void Function()? onDownload,
  void Function()? onRemoveDownload,
}) {
  return [
    if (onDownload != null)
      MenuItem(
        label: const Text('Download'),
        icon: const Icon(LucideIcons.download),
        onSelected: (_) => onDownload(),
      ),
    if (onRemoveDownload != null)
      MenuItem(
        label: const Text('Remove Download'),
        icon: const Icon(LucideIcons.trash2),
        onSelected: (_) => onRemoveDownload(),
      ),
  ];
}

List<ContextMenuEntry> _refreshEntries({
  VoidCallback? onRefreshCovers,
}) {
  return [
    if (onRefreshCovers != null)
      MenuItem(
        label: const Text('Refresh Covers'),
        icon: const Icon(LucideIcons.imageDown),
        onSelected: (_) => onRefreshCovers(),
      ),
  ];
}
