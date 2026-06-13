import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfTocDrawer extends HookConsumerWidget {
  final PdfViewerController controller;
  final List<PdfOutlineNode> toc;
  final int seriesId;
  final int chapterId;
  const PdfTocDrawer({
    super.key,
    required this.controller,
    required this.toc,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = useState(GlobalKey());
    final hasScrolled = useState(false);

    final list = _getOutlineList(toc, 0).toList();
    final nav = ref.watch(
      readerNavigationProvider(seriesId: seriesId, chapterId: chapterId),
    );

    return Drawer(
      child: Async(
        asyncValue: nav,
        data: (nav) {
          final currentDestIndex = list.lastIndexWhere(
            (item) => (item.node.dest?.pageNumber ?? 0) <= nav.currentPage,
          );

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (selectedKey.value.currentContext != null &&
                !hasScrolled.value) {
              await Scrollable.ensureVisible(
                selectedKey.value.currentContext!,
                alignment: 0.2,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              hasScrolled.value = true;
            }
          });

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: LayoutConstants.mediumPadding,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: LayoutConstants.smallPadding,
                  crossAxisAlignment: .start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LayoutConstants.mediumPadding,
                      ),
                      child: Text(
                        'Table of Contents',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    ...list.indexed.map(
                      (entry) {
                        final (index, item) = entry;
                        final selected = index == currentDestIndex + 1;
                        return ListTile(
                          key: index == currentDestIndex
                              ? selectedKey.value
                              : null,
                          onTap: () => controller.goToDest(item.node.dest),
                          contentPadding: EdgeInsetsGeometry.only(
                            left:
                                item.level + 1 * LayoutConstants.mediumPadding,
                            right: LayoutConstants.mediumPadding,
                          ),
                          selected: selected,
                          title: Text(
                            item.node.title,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Recursively create outline indent structure
  Iterable<({PdfOutlineNode node, int level})> _getOutlineList(
    List<PdfOutlineNode>? outline,
    int level,
  ) sync* {
    if (outline == null) return;
    for (var node in outline) {
      yield (node: node, level: level);
      yield* _getOutlineList(node.children, level + 1);
    }
  }
}
