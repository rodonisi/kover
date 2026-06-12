import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/utils/sentry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'sentry_repository.g.dart';

@riverpod
SentryRepository sentryRepository(Ref ref) {
  final repo = SentryRepository();

  ref.listen(generalSettingsProvider, (previous, next) async {
    next.whenData((settings) async {
      if (settings.sendDiagnostics) {
        await repo.init();
      } else {
        await repo.disable();
      }
    });
  }, fireImmediately: true);

  return repo;
}

class SentryRepository {
  /// Initialize Sentry if it's not already enabled.
  Future<void> init() async {
    if (Sentry.isEnabled) return;

    await SentryFlutter.init(
      sentryOptionsConfiguration,
    );
    log.info('sentry initialized');
  }

  /// Disable Sentry by closing the client and preventing further events from
  /// being sent.
  Future<void> disable() async {
    await Sentry.close();
    log.info('sentry disabled');
  }
}
