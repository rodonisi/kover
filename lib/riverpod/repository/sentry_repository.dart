import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/utils/sentry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'sentry_repository.g.dart';

@riverpod
SentryRepository sentryRepository(Ref ref) {
  final repo = SentryRepository();

  ref.listen(generalSettingsProvider, (previous, next) async {
    next.whenData((settings) async {
      if (settings.sendUsageData) {
        await repo.init();
      } else {
        await repo.disable();
      }
    });
  }, fireImmediately: true);

  return repo;
}

class SentryRepository {
  Future<void> init() async {
    if (Sentry.isEnabled) return;

    await SentryFlutter.init(
      sentryOptionsConfiguration,
    );
  }

  Future<void> disable() async {
    await Sentry.close();
  }
}
