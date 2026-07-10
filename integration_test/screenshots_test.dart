import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kover/main.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/pages/reader/overlay/reader_controls.dart';
import 'package:kover/pages/reader/overlay/reader_overlay.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/providers/settings/common_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/riverpod/providers/settings/oneoffs.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('dark mode screenshots', () {
    setUp(() {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    });
    tearDown(() {
      binding.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    testWidgets("page screenshots", (WidgetTester tester) async {
      final container = await initializeApp(tester);

      await takePageScreenshot(
        "home",
        route: const HomeRoute().location,
        tester: tester,
        container: container,
        binding: binding,
      );

      await takePageScreenshot(
        "want_to_read",
        route: const WantToReadRoute().location,
        tester: tester,
        container: container,
        binding: binding,
      );

      await takePageScreenshot(
        "menu",
        route: const MenuRoute().location,
        tester: tester,
        container: container,
        binding: binding,
      );

      await takePageScreenshot(
        "settings",
        route: const SettingsRoute().location,
        tester: tester,
        container: container,
        binding: binding,
      );

      await takePageScreenshot(
        'all_series',
        route: const AllSeriesRoute().location,
        tester: tester,
        container: container,
        binding: binding,
      );

      await takePageScreenshot(
        'collections',
        route: const CollectionsRoute().location,
        tester: tester,
        container: container,
        binding: binding,
      );

      await takePageScreenshot(
        'reading_lists',
        route: const ReadingListsRoute().location,
        tester: tester,
        container: container,
        binding: binding,
      );

      await takePageScreenshot(
        'series_details',
        route: const SeriesDetailRoute(seriesId: 10).location,
        tester: tester,
        container: container,
        binding: binding,
      );
    });

    testWidgets('image reader screenshot', (tester) async {
      final targetSeries = 13;
      final targetChapter = 21;
      final targetPage = 0;

      final container = await initializeApp(tester);

      container.listen(seriesProvider(seriesId: targetSeries), (_, _) {});
      container.listen(
        readerProvider(seriesId: targetSeries, chapterId: targetChapter),
        (_, _) {},
      );
      container.listen(
        readerNavigationProvider(
          seriesId: targetSeries,
          chapterId: targetChapter,
        ),
        (_, _) {},
      );
      container.listen(
        commonReaderSettingsProvider(seriesId: targetSeries),
        (_, _) {},
      );
      container.listen(
        imageReaderSettingsProvider(seriesId: targetSeries),
        (_, _) {},
      );
      container.listen(
        imagePageProvider(chapterId: targetChapter, page: targetPage),
        (_, _) {},
      );

      container
          .read(routerProvider)
          .go(
            ReaderRoute(
              seriesId: targetSeries,
              chapterId: targetChapter,
            ).location,
          );

      await tester.pumpAndSettle();

      await container
          .read(
            readerNavigationProvider(
              seriesId: targetSeries,
              chapterId: targetChapter,
            ).notifier,
          )
          .jumpToPage(targetPage);

      await tester.pumpAndSettle();

      await binding.screenshot(tester, 'image_reader');

      final center = tester.getCenter(find.byType(ReaderOverlay));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      await binding.screenshot(tester, 'image_reader_overlay');

      while (find.byType(ReaderSettingsButton).evaluate().isEmpty) {
        await tester.pump();
      }
      await tester.tap(find.byType(ReaderSettingsButton));
      await tester.pumpAndSettle();
      await binding.screenshot(tester, 'image_reader_settings');
    });
  });

  group('light mode screenshots', () {
    setUp(() {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    });
    tearDown(() {
      binding.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    testWidgets('epub reader screenshot', (tester) async {
      final targetSeries = 1;
      final targetChapter = 38;
      final targetPage = 10;

      final container = await initializeApp(tester);
      container.listen(seriesProvider(seriesId: targetSeries), (_, _) {});
      container.listen(
        readerProvider(seriesId: targetSeries, chapterId: targetChapter),
        (_, _) {},
      );
      container.listen(
        readerNavigationProvider(
          seriesId: targetSeries,
          chapterId: targetChapter,
        ),
        (_, _) {},
      );
      final sub = container.listen(
        epubNavigationProvider(
          seriesId: targetSeries,
          chapterId: targetChapter,
        ),
        (_, _) {},
      );
      container
          .read(routerProvider)
          .go(
            ReaderRoute(
              seriesId: targetSeries,
              chapterId: targetChapter,
            ).location,
          );
      await tester.pump(5.seconds);

      var chapterReady = false;
      var targetPageReady = false;
      var spinner = find.byType(CircularProgressIndicator);

      var counter = 0;
      while (!chapterReady || spinner.evaluate().isNotEmpty) {
        if (++counter % 1000 == 0) {
          log.debug('waiting for chapter to be ready');
        }
        await tester.pump();
        final state = sub.read();
        chapterReady = state.value?.ready ?? false;
      }
      await tester.pump();

      if (sub.read().value?.page != targetPage) {
        log.debug('jumping to target page $targetPage');
        await container
            .read(
              epubNavigationProvider(
                seriesId: targetSeries,
                chapterId: targetChapter,
              ).notifier,
            )
            .jumpToPage(targetPage);

        while (!targetPageReady || spinner.evaluate().isNotEmpty) {
          if (++counter % 1000 == 0) {
            log.debug('waiting for target page to be ready');
          }
          await tester.pump();
          final state = sub.read();
          targetPageReady =
              state.value?.page == targetPage && (state.value?.ready ?? false);
        }
        await tester.pump();
      }

      if (sub.read().value?.subpage != 0) {
        log.debug('jumping to subpage 0');
        await container
            .read(
              epubNavigationProvider(
                seriesId: targetSeries,
                chapterId: targetChapter,
              ).notifier,
            )
            .jumpToSubpage(0);
        await tester.pump(1.seconds);
      }

      await binding.screenshot(tester, 'epub_reader');

      final center = tester.getCenter(find.byType(Scaffold));
      await tester.tapAt(center);
      await tester.pump(500.ms);
      await binding.screenshot(tester, 'epub_reader_overlay');

      await tester.tap(find.byType(ReaderSettingsButton));
      await tester.pump(1000.ms);
      await binding.screenshot(tester, 'epub_reader_settings');
    });
  });

  group('theme modes screenshots', () {
    testWidgets('light mode screenshot', (tester) async {
      await initializeApp(
        tester,
        additionalOverrides: [
          themeProvider.overrideWithBuild(
            (_, _) => const ThemeModel(mode: ThemeMode.light),
          ),
        ],
      );
      await binding.screenshot(tester, 'light_mode');
    });

    testWidgets('outlined theme screenshot', (tester) async {
      await initializeApp(
        tester,
        additionalOverrides: [
          themeProvider.overrideWithBuild(
            (_, _) => const ThemeModel(mode: .dark, outlined: true),
          ),
        ],
      );
      await binding.screenshot(tester, 'outlined_mode');
    });
  });
}

class EpubReaderPage {}

Future<ProviderContainer> initializeApp(
  WidgetTester tester, {
  List<Override> additionalOverrides = const [],
}) async {
  const url = String.fromEnvironment('TEST_URL');
  const apiKey = String.fromEnvironment('TEST_API_KEY');
  final container = ProviderContainer(
    overrides: [
      credentialsProvider.overrideWithBuild(
        (_, _) => const CredentialsState(url: url, apiKey: apiKey),
      ),
      oneOffsProvider.overrideWithBuild(
        (_, _) => const OneOffsState(monitoringOptOutPopupShown: true),
      ),
      ...additionalOverrides,
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
  var fetching = true;
  container.listen(syncManagerProvider, (previous, next) {
    if (next is IdleState) {
      fetching = false;
    }
  });

  var count = 0;
  while (fetching) {
    await tester.pump();
    if (++count % 100 == 0) {
      log.debug('waiting for sync to finish');
    }
  }
  return container;
}

Future<void> takePageScreenshot(
  String screenshotName, {
  required String route,
  required WidgetTester tester,
  required ProviderContainer container,
  required IntegrationTestWidgetsFlutterBinding binding,
}) async {
  container.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  await binding.screenshot(
    tester,
    screenshotName,
  );
}

extension on IntegrationTestWidgetsFlutterBinding {
  Future<void> screenshot(WidgetTester tester, String screenshotName) async {
    if (Platform.isAndroid) {
      try {
        await convertFlutterSurfaceToImage();
      } catch (_) {}
      await tester.pump();
    }

    await takeScreenshot(screenshotName);
  }
}
