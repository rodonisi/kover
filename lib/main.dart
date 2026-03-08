import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/managers/download_manager.dart';
import 'package:kover/riverpod/managers/sync_manager.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/theme.dart';
import 'package:kover/sync/background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundTask();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return EagerProviders(
      child: MaterialApp.router(
        title: 'Kover',
        debugShowCheckedModeBanner: false,
        theme: theme.lightTheme,
        darkTheme: theme.darkTheme,
        themeMode: theme.mode,
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}

/// Keeps providers that need to be initialized at app startup alive.
/// This ensures that they are not disposed when not in use, which can lead to
/// issues if they are needed again later.
class EagerProviders extends ConsumerWidget {
  final Widget child;

  const EagerProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncManagerProvider);
    ref.watch(downloadManagerProvider);

    return child;
  }
}
