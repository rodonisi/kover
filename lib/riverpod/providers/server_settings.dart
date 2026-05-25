import 'package:kover/riverpod/repository/server_settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_settings.g.dart';

@riverpod
Stream<String?> serverVersion(Ref ref) {
  final serverSettings = ref.watch(serverSettingsRepositoryProvider);
  return serverSettings.watchServerVersion();
}
