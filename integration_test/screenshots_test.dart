import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kover/main.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/reader/epub_reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/providers/settings/oneoffs.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/utils/logging.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  for (final brightness in [Brightness.light, Brightness.dark]) {
    group("screenshots ${brightness.name}", () {
      setUp(() {
        binding.platformDispatcher.platformBrightnessTestValue = brightness;
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
    });
  }

  // testWidgets('epub reader screenshot', (tester) async {
  //   final targetSeries = 1;
  //   final targetChapter = 38;
  //   final targetPage = 11;
  //
  //   final container = await initializeApp(tester);
  //   container
  //       .read(routerProvider)
  //       .go(
  //         ReaderRoute(
  //           seriesId: targetSeries,
  //           chapterId: targetChapter,
  //         ).location,
  //       );
  //
  //   await tester.pump(Duration(seconds: 30));
  //
  //   var chapterReady = false;
  //   container.listen(
  //     epubNavigationProvider(seriesId: targetSeries, chapterId: targetPage),
  //     (
  //       previous,
  //       next,
  //     ) {
  //       log.debug('epub navigation state changed: $next');
  //       next.whenData((data) {
  //         chapterReady = data.ready;
  //       });
  //     },
  //     fireImmediately: true,
  //   );
  //
  //   await container
  //       .read(
  //         epubNavigationProvider(
  //           seriesId: targetSeries,
  //           chapterId: targetChapter,
  //         ).notifier,
  //       )
  //       .jumpToPage(targetPage);
  //
  //   while (!chapterReady) {
  //     await tester.pump(const Duration(seconds: 1));
  //     log.debug('waiting for chapter to be ready');
  //   }
  //
  //   await binding.screenshot(
  //     tester,
  //     'epub_reader',
  //   );
  // });
}

Future<ProviderContainer> initializeApp(WidgetTester tester) async {
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
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: GenericDeviceFrame(child: const App()),
    ),
  );
  var fetching = true;
  container.listen(syncManagerProvider, (previous, next) {
    if (next is IdleState) {
      fetching = false;
    }
  });

  while (fetching) {
    await tester.pump(const Duration(seconds: 5));
    log.debug('waiting for sync to finish');
  }
  return container;
}

class GenericDeviceFrame extends StatelessWidget {
  final Widget child;
  final Size
  screenSize; // e.g., Size(390, 844) for standard mobile aspect ratio

  const GenericDeviceFrame({
    super.key,
    required this.child,
    this.screenSize = const Size(375, 812), // Generic smartphone ratio
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: LayoutConstants.largeEdgeInsets,
        child: Directionality(
          textDirection: .ltr,
          child: Center(
            child: Container(
              // Outer frame decoration (the "bezel")
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A), // Dark matte generic bezel
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SizedBox(
                width: screenSize.width,
                height: screenSize.height,
                // Clip the app content to match the bezel's inner curve
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: MediaQuery(
                    // Injects simulated screen metrics into your app
                    data: MediaQueryData(
                      size: screenSize,
                      padding: const EdgeInsets.only(top: 44, bottom: 34),
                      viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
                    ),
                    child: Scaffold(
                      body: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      await tester.pumpAndSettle();
    }
    final platform = Platform.operatingSystem;
    final brightness = tester.platformDispatcher.platformBrightness;
    final mode = brightness == Brightness.dark ? 'dark' : 'light';

    log.debug('taking screenshot $platform/$mode/$screenshotName');

    await takeScreenshot('$platform/$mode/$screenshotName');
  }
}
