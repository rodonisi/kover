import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/chapter_model.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/chapters_grid.dart';
import 'package:kover/widgets/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChaptersPage extends HookConsumerWidget {
  final int seriesId;
  final int? volumeId;
  const ChaptersPage({super.key, required this.seriesId, this.volumeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideRead = useState(false);
    final chapters = ref.watch(
      seriesDetailProvider(
        seriesId: seriesId,
      ).select((state) {
        if (volumeId != null) {
          return state.value?.volumes
                  .where((volume) => volume.id == volumeId)
                  .singleOrNull
                  ?.chapters ??
              [];
        }
        return (hideRead.value
                ? state.value?.unreadChapters
                : state.value?.chapters) ??
            [];
      }),
    );

    return _ChaptersPage(
      title: 'Chapters',
      seriesId: seriesId,
      chapters: chapters,
      hideReadToggle: IconButton(
        onPressed: () => hideRead.value = !hideRead.value,
        tooltip: hideRead.value ? 'Show read' : 'Hide read',
        icon: Icon(
          hideRead.value ? LucideIcons.eyeOff : LucideIcons.eye,
        ),
      ),
    );
  }
}

class StorylinePage extends ConsumerWidget {
  final int seriesId;
  const StorylinePage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(
      seriesDetailProvider(
        seriesId: seriesId,
      ).select((state) {
        return state.value?.storyline ?? [];
      }),
    );

    return _ChaptersPage(
      title: 'Storyline',
      seriesId: seriesId,
      chapters: chapters,
    );
  }
}

class SpecialsPage extends ConsumerWidget {
  final int seriesId;
  const SpecialsPage({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(
      seriesDetailProvider(
        seriesId: seriesId,
      ).select((state) {
        return state.value?.specials ?? [];
      }),
    );

    return _ChaptersPage(
      title: 'Specials',
      seriesId: seriesId,
      chapters: chapters,
    );
  }
}

class _ChaptersPage extends HookConsumerWidget {
  final String title;
  final int seriesId;
  final List<ChapterModel> chapters;
  final Widget? hideReadToggle;
  const _ChaptersPage({
    required this.title,
    required this.seriesId,
    required this.chapters,
    this.hideReadToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(title),
              actions: [?hideReadToggle],
            ),
            SliverPadding(
              padding: LayoutConstants.smallEdgeInsets,
              sliver: ChaptersGrid(
                seriesId: seriesId,
                chapters: chapters,
              ),
            ),
            const SliverBottomPadding(),
          ],
        ),
      ),
    );
  }
}
