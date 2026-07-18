import 'dart:async';
import 'dart:io';

import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/models/user_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth.g.dart';

class NoCredentialsException implements Exception {}

Duration? _retry(int retryCount, Object error) {
  // Never retry missing credentials
  if (error is NoCredentialsException) return null;

  // Never retry network errors (offline) - fail fast
  if (error is SocketException || error is TimeoutException) return null;

  // Retry other errors up to 3 times
  if (retryCount >= 3) return null;

  return Duration(milliseconds: 200 * (1 << retryCount));
}

@Riverpod(retry: _retry, keepAlive: true)
@JsonPersist()
class CurrentUser extends _$CurrentUser {
  @override
  Future<UserModel> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    ref.listen(
      credentialsProvider,
      (_, _) => ref.invalidateSelf(asReload: true),
    );

    final apiKey = ref.watch(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) throw NoCredentialsException();

    if (state.hasValue) {
      unawaited(_refreshUser(apiKey: apiKey));
      return state.requireValue;
    }

    return await _fetchUser(apiKey: apiKey);
  }

  Future<void> _refreshUser({required String apiKey}) async {
    try {
      final user = await _fetchUser(apiKey: apiKey);
      state = AsyncValue.data(user);
    } catch (e) {
      log.warning(
        'Failed to refresh user',
        attributes: {
          'error': e,
        },
      );
    }
  }

  Future<UserModel> _fetchUser({required String apiKey}) async {
    final client = ref.watch(restClientProvider);
    final res = await client.apiPluginAuthenticatePost(
      apiKey: apiKey,
      pluginName: 'kover',
    );
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to authenticate: ${res.error}');
    }
    return UserModel.fromUserDto(res.body!);
  }
}
