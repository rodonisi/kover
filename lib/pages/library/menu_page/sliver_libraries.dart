import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/library_model.dart';
import 'package:kover/pages/library/menu_page/app_list_tile.dart';
import 'package:kover/riverpod/providers/library.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SliverLibraries extends ConsumerWidget {
  const SliverLibraries({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libs = ref.watch(librariesProvider);

    return AsyncSliver(
      asyncValue: libs,
      data: (data) {
        return SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: LayoutConstants.mediumPadding,
            vertical: LayoutConstants.smallPadding,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == data.length - 1
                        ? 0
                        : LayoutConstants.smallPadding,
                  ),
                  child: LibraryListTile(lib: data[index]),
                );
              },
              childCount: data.length,
            ),
          ),
        );
      },
    );
  }
}

class LibraryListTile extends StatelessWidget {
  const LibraryListTile({
    super.key,
    required this.lib,
  });

  final LibraryModel lib;

  @override
  Widget build(BuildContext context) {
    final leading = Icon(switch (lib.type) {
      .book || .lightNovel => LucideIcons.bookText,
      .manga || .comic || .comicLegacy => LucideIcons.bookOpen,
      .image => LucideIcons.image,
      _ => LucideIcons.fileQuestionMark,
    });

    return AppListTile(
      title: lib.name,
      icon: leading,
      onTap: () => SeriesRoute(libraryId: lib.id).push(context),
    );
  }
}
