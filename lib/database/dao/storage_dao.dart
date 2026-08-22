import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/riverpod_storage.dart';

part 'storage_dao.g.dart';

@DriftAccessor(tables: [RiverpodStorage])
class StorageDao extends DatabaseAccessor<AppDatabase> with _$StorageDaoMixin {
  StorageDao(super.attachedDatabase);

  /// Delete all entries from [RiverpodStorage]
  Future<void> clear() async {
    await delete(riverpodStorage).go();
  }

  /// Delete entry [key]
  Future<void> deleteKey(String key) async {
    await (delete(riverpodStorage)..where((row) => row.key.equals(key))).go();
  }

  /// Delete entries past their expiration date
  Future<void> deleteOutOfDate() async {
    await (delete(
      riverpodStorage,
    )..where((row) => row.expireAt.isSmallerThan(currentDateAndTime))).go();
  }

  /// Read entry for [key]
  Future<RiverpodStorageData?> read(String key) async {
    return await (select(
      riverpodStorage,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
  }

  /// Write [entry]
  Future<void> write(RiverpodStorageCompanion entry) async {
    await (into(riverpodStorage).insertOnConflictUpdate(entry));
  }
}
