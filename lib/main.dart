import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/sync/background.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/breakpoints.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundTask();

  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://b5a6b68eea23284eb215f1661c8661e2@o4511480670060544.ingest.de.sentry.io/4511480676679760';
      options.sendDefaultPii = false;
      options.enableLogs = true;
      options.tracesSampleRate = 1.0;
      // ignore: experimental_member_use
      options.profilesSampleRate = 1.0;
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(
      ProviderScope(
        child: SentryWidget(
          child: const App(),
        ),
      ),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return BreakpointsWatcher(
      child: Async(
        asyncValue: theme,
        data: (theme) => MaterialApp.router(
          title: 'Kover',
          debugShowCheckedModeBanner: false,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.mode,
          routerConfig: ref.watch(routerProvider),
        ),
        loading: () => const SizedBox.shrink(),
      ),
    );
  }
}
