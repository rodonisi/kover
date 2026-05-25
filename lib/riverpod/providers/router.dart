import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kover/pages/download_queue/download_queue_page.dart';
import 'package:kover/pages/home/home_page.dart';
import 'package:kover/pages/menu_page/menu_page.dart';
import 'package:kover/pages/menu_page/series_page/series_page.dart';
import 'package:kover/pages/reader/reader_page.dart';
import 'package:kover/pages/series_detail_page/chapter_detail_page/chapter_detail_page.dart';
import 'package:kover/pages/series_detail_page/chapters_page/chapters_page.dart';
import 'package:kover/pages/series_detail_page/series_detail_page.dart';
import 'package:kover/pages/series_detail_page/volume_detail_page/volume_detail_page.dart';
import 'package:kover/pages/series_detail_page/volumes_page/volumes_page.dart';
import 'package:kover/pages/settings/settings_page.dart';
import 'package:kover/pages/want_to_read_page/want_to_read_page.dart';
import 'package:kover/widgets/util/navigator_container.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

final navigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(Ref ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: $appRoutes,
  );
}

@TypedStatefulShellRoute<AppShellRoute>(
  branches: [
    TypedStatefulShellBranch<HomeBranch>(
      routes: [
        TypedGoRoute<HomeRoute>(
          path: '/',
          routes: [
            TypedGoRoute<SeriesDetailRoute>(
              path: 'series/:seriesId',
              routes: [
                TypedGoRoute<VolumesRoute>(
                  path: 'volumes',
                  routes: [
                    TypedGoRoute<VolumeDetailRoute>(
                      path: ':volumeId',
                      routes: [
                        TypedGoRoute<VolumeChaptersRoute>(path: 'chapters'),
                      ],
                    ),
                  ],
                ),
                TypedGoRoute<ChaptersRoute>(
                  path: 'chapters',
                  routes: [
                    TypedGoRoute<ChapterDetailRoute>(path: ':chapterId'),
                  ],
                ),
                TypedGoRoute<StorylineRoute>(path: 'storyline'),
                TypedGoRoute<SpecialsRoute>(path: 'specials'),
              ],
            ),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<WantToReadBranch>(
      routes: [
        TypedGoRoute<WantToReadRoute>(path: '/want-to-read'),
      ],
    ),
    TypedStatefulShellBranch<LibraryBranch>(
      routes: [
        TypedGoRoute<LibraryRoute>(
          path: '/menu',
          routes: [
            TypedGoRoute<AllSeriesRoute>(
              path: 'all-series',
            ),
            TypedGoRoute<SeriesRoute>(
              path: 'library/:libraryId',
            ),
            TypedGoRoute<DownloadQueueRoute>(
              path: 'download-queue',
            ),
            TypedGoRoute<SettingsRoute>(
              path: 'settings',
            ),
          ],
        ),
      ],
    ),
  ],
)
class AppShellRoute extends StatefulShellRouteData {
  const AppShellRoute();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return NavigatorContainer(navigationShell: navigationShell);
  }
}

class HomeBranch extends StatefulShellBranchData {
  const HomeBranch();
}

class WantToReadBranch extends StatefulShellBranchData {
  const WantToReadBranch();
}

class LibraryBranch extends StatefulShellBranchData {
  const LibraryBranch();
}

class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

class WantToReadRoute extends GoRouteData with $WantToReadRoute {
  const WantToReadRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const WantToReadPage();
}

class LibraryRoute extends GoRouteData with $LibraryRoute {
  const LibraryRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MenuPage();
}

class AllSeriesRoute extends GoRouteData with $AllSeriesRoute {
  const AllSeriesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AllSeriesPage();
}

class SeriesRoute extends GoRouteData with $SeriesRoute {
  final int libraryId;

  const SeriesRoute({required this.libraryId});

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LibrarySeriesPage(libraryId: libraryId);
}

class SeriesDetailRoute extends GoRouteData with $SeriesDetailRoute {
  const SeriesDetailRoute({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      SeriesDetailPage(seriesId: seriesId);
}

class VolumesRoute extends GoRouteData with $VolumesRoute {
  const VolumesRoute({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return VolumesPage(
      seriesId: seriesId,
    );
  }
}

class ChaptersRoute extends GoRouteData with $ChaptersRoute {
  const ChaptersRoute({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ChaptersPage(seriesId: seriesId);
  }
}

class SpecialsRoute extends GoRouteData with $SpecialsRoute {
  const SpecialsRoute({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return SpecialsPage(seriesId: seriesId);
  }
}

class StorylineRoute extends GoRouteData with $StorylineRoute {
  const StorylineRoute({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return StorylinePage(seriesId: seriesId);
  }
}

class VolumeDetailRoute extends GoRouteData with $VolumeDetailRoute {
  VolumeDetailRoute({required this.seriesId, required this.volumeId});

  final int seriesId;
  final int volumeId;

  @override
  Widget build(BuildContext context, GoRouterState state) => VolumeDetailPage(
    volumeId: volumeId,
  );
}

class ChapterDetailRoute extends GoRouteData with $ChapterDetailRoute {
  const ChapterDetailRoute({required this.seriesId, required this.chapterId});

  final int seriesId;
  final int chapterId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ChapterDetailPage(chapterId: chapterId);
  }
}

class VolumeChaptersRoute extends GoRouteData with $VolumeChaptersRoute {
  const VolumeChaptersRoute({required this.seriesId, required this.volumeId});

  final int seriesId;
  final int volumeId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ChaptersPage(
      seriesId: seriesId,
      volumeId: volumeId,
    );
  }
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsPage();
}

class DownloadQueueRoute extends GoRouteData with $DownloadQueueRoute {
  const DownloadQueueRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DownloadQueuePage();
}

@TypedGoRoute<ReaderRoute>(path: '/reader/:seriesId')
class ReaderRoute extends GoRouteData with $ReaderRoute {
  final int seriesId;
  final int? chapterId;

  const ReaderRoute({
    required this.seriesId,
    this.chapterId,
  });

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return MaterialPage(
      key: state.pageKey,
      fullscreenDialog: true,
      child: ReaderPage(
        seriesId: seriesId,
        chapterId: chapterId,
      ),
    );
  }
}
