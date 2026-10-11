import 'package:kover/models/chapter_model.dart';
import 'package:kover/widgets/cards/chapter_card.dart';
import 'package:kover/widgets/list_page/entities_list_page.dart';
import 'package:kover/widgets/lists/list_entries/chapter_list_entry.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

class ChaptersListPage extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final AsyncValue<List<ChapterModel>> chapters;
  final Widget? sortMenu;
  final bool hideAction;

  const new({
    super.key,
    required this.title,
    required this.controller,
    required this.chapters,
    this.sortMenu,
    this.hideAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return EntitiesListPage<ChapterModel>(
      title: title,
      filterController: controller,
      items: chapters,
      sortMenu: sortMenu,
      gridBuilder: (context, chapter) => ChapterCard(
        key: ValueKey(chapter.id),
        chapterId: chapter.id,
        seriesId: chapter.seriesId,
        hideAction: hideAction,
      ),
      listBuilder: (context, chapter) => ChapterListEntry(
        key: ValueKey(chapter.id),
        chapterId: chapter.id,
        seriesId: chapter.seriesId,
      ),
    );
  }
}
