import 'package:kover/pages/series_detail_page/sliver_metadata_display.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/series_detail_page/chapter_detail_page/chapter_app_bar.dart';
import 'package:kover/widgets/details/metadata_sections.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';

class ChapterDetailPage extends ConsumerWidget {
  final int chapterId;

  const ChapterDetailPage({
    super.key,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: MetadataScope(
        metadataId: .chapter(chapterId: chapterId),
        child: CustomScrollView(
          slivers: [
            ChapterAppBar(
              chapterId: chapterId,
            ),
            const SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverMetadataDisplay(),
            ),
            const SliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}
