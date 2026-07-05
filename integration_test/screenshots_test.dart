import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kover/main.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/providers/settings/oneoffs.dart';
import 'package:kover/riverpod/providers/theme.dart';
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
      });
    });
  }
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
      child: const App(),
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
