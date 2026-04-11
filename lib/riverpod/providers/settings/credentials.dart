import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'credentials.freezed.dart';
part 'credentials.g.dart';

@freezed
sealed class CredentialsState with _$CredentialsState {
  const factory CredentialsState({
    String? url,
    String? apiKey,
  }) = _CredentialsState;

  factory CredentialsState.fromJson(Map<String, Object?> json) =>
      _$CredentialsStateFromJson(json);
}

@Riverpod(keepAlive: true)
@JsonPersist()
class Credentials extends _$Credentials {
  static const String persistKey = 'credentials';

  @override
  Future<CredentialsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      key: persistKey,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    return state.value ?? const CredentialsState();
  }

  void updateCredentials(CredentialsState settings) {
    state = AsyncValue.data(settings);
  }
}

@Riverpod(keepAlive: true)
String? apiKey(Ref ref) {
  final settings = ref.watch(credentialsProvider).value;
  return settings?.apiKey;
}

enum LoginStatus { noCredentials, loading, loggedIn, error }

@riverpod
LoginStatus loginStatus(Ref ref) {
  final settings = ref.watch(credentialsProvider);
  final user = ref.watch(currentUserProvider);

  if (settings.isLoading) return .loading;

  if (settings.hasError) return .error;

  final settingsState = settings.value!;
  if ((settingsState.url?.isEmpty ?? true) ||
      (settingsState.apiKey?.isEmpty ?? true)) {
    return .noCredentials;
  }

  if (user.isLoading) return .loading;

  if (user.hasError) return .error;

  return .loggedIn;
}
