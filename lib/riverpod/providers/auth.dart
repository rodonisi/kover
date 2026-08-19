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

class CertificateValidationException implements Exception {
  CertificateValidationException(this.cause);

  final Object cause;

  @override
  String toString() => 'Certificate validation failed: $cause';
}

bool isCertificateValidationError(Object? error) {
  if (error is CertificateValidationException || error is HandshakeException) {
    return true;
  }

  final message = error.toString().toLowerCase();
  return message.contains('certificate verify failed') ||
      message.contains('certificate validation failed') ||
      message.contains('cert_path_validator_exception');
}

Duration? _retry(int retryCount, Object error) {
  // Never retry missing credentials
  if (error is NoCredentialsException) return null;

  // Never retry connectivity or TLS-certificate errors - fail fast.
  // A certificate validation failure cannot succeed without changing the
  // server certificate or the configured URL.
  if (error is SocketException ||
      error is TimeoutException ||
      isCertificateValidationError(error)) {
    return null;
  }

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

    // Authentication also depends on transport options such as certificate
    // validation, not just the API key. Watching the complete credentials
    // state ensures saving any of these settings refreshes the connection.
    final credentials = ref.watch(credentialsProvider).value;
    final apiKey = credentials?.apiKey;
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
    } catch (error, stackTrace) {
      log.warning(
        'Failed to refresh user',
        attributes: {
          'error': error,
        },
      );

      // A refresh normally keeps the last known user visible if the network
      // or server is temporarily unavailable. A rejected TLS certificate is
      // actionable, though: surface it so the user can enable the explicit
      // certificate-validation exception or correct the server certificate.
      if (isCertificateValidationError(error)) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<UserModel> _fetchUser({required String apiKey}) async {
    final client = ref.watch(restClientProvider);
    try {
      final res = await client.apiPluginAuthenticatePost(
        apiKey: apiKey,
        pluginName: 'kover',
      );
      if (!res.isSuccessful || res.body == null) {
        throw switch (res.error) {
          final Exception error => error,
          final error => Exception('Failed to authenticate: $error'),
        };
      }
      return UserModel.fromUserDto(res.body!);
    } catch (error) {
      if (error is CertificateValidationException) rethrow;
      if (isCertificateValidationError(error)) {
        throw CertificateValidationException(error);
      }
      rethrow;
    }
  }
}
