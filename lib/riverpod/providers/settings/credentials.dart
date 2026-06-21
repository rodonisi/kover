import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/repository/secure_storage.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'credentials.freezed.dart';
part 'credentials.g.dart';

@freezed
sealed class CredentialsState with _$CredentialsState {
  const factory CredentialsState({
    String? url,
    String? apiKey,
    @Default({}) Map<String, String> customHeaders,
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
      ref.watch(secureStorageProvider),
      key: persistKey,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    return state.value ?? const CredentialsState();
  }

  void updateCredentials(CredentialsState settings) {
    state = AsyncValue.data(settings);
  }

  void addHeader(String key, String value) {
    final trimmedKey = key.trim();
    final trimmedValue = value.trim();
    if (trimmedKey.isEmpty || trimmedValue.isEmpty) return;
    final currentState = state.value ?? const CredentialsState();
    final updatedHeaders = Map<String, String>.from(currentState.customHeaders)
      ..[trimmedKey] = trimmedValue;
    updateCredentials(currentState.copyWith(customHeaders: updatedHeaders));
  }

  void removeHeader(String key) {
    final currentState = state.value ?? const CredentialsState();
    final updatedHeaders = Map<String, String>.from(currentState.customHeaders)
      ..remove(key);
    updateCredentials(currentState.copyWith(customHeaders: updatedHeaders));
  }

  void removeAllHeaders() {
    final currentState = state.value ?? const CredentialsState();
    updateCredentials(currentState.copyWith(customHeaders: {}));
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
