import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/sync/background.dart';
import 'package:kover/utils/sentry.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/breakpoints.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundTask();

  await initializeSentry(
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
