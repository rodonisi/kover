import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.freezed.dart';
part 'secure_storage.g.dart';

const secureStorageIOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
  synchronizable: true,
);

@freezed
sealed class SecureStorageEntry with _$SecureStorageEntry {
  const factory SecureStorageEntry({
    required String key,
    required String value,
    DateTime? expireAt,
    String? destroyKey,
  }) = _SecureStorageEntry;

  factory SecureStorageEntry.fromJson(Map<String, Object?> json) =>
      _$SecureStorageEntryFromJson(json);
}

@Riverpod(keepAlive: true)
Storage<String, String> secureStorage(Ref ref) {
  return SecureStorageRepository();
}

final class SecureStorageRepository extends Storage<String, String> {
  final storage = const FlutterSecureStorage(
    iOptions: secureStorageIOSOptions,
  );

  SecureStorageRepository();

  @override
  FutureOr<void> delete(String key) async {
    await storage.delete(key: key);
  }

  @override
  Future<void> deleteOutOfDate() async {
    try {
      final entries = await storage.readAll();
      final now = DateTime.timestamp();
      for (final entry in entries.entries) {
        final storageEntry = SecureStorageEntry.fromJson(
          jsonDecode(entry.value),
        );
        if (storageEntry.expireAt != null &&
            storageEntry.expireAt!.isBefore(now)) {
          await storage.delete(key: entry.key);
        }
      }
    } catch (e, stacktrace) {
      log.error(
        'Failed to delete out-of-date entries',
        error: e,
        stacktrace: stacktrace,
      );
    }
  }

  @override
  FutureOr<PersistedData<String>?> read(String key) async {
    final value = await storage.read(key: key);
    if (value == null) {
      return null;
    }

    final entry = SecureStorageEntry.fromJson(jsonDecode(value));

    return PersistedData(entry.value);
  }

  @override
  FutureOr<void> write(String key, String value, StorageOptions options) async {
    final entry = SecureStorageEntry(
      key: key,
      value: value,
      expireAt: options.cacheTime.duration != null
          ? DateTime.timestamp().add(options.cacheTime.duration!)
          : null,
      destroyKey: options.destroyKey,
    );

    await storage.write(key: key, value: jsonEncode(entry.toJson()));
  }
}
