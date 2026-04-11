import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/tables/riverpod_storage.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';

part 'riverpod_dao.g.dart';

@DriftAccessor(
  tables: [RiverpodStorage],
)
class RiverpodDao extends DatabaseAccessor<AppDatabase>
    with _$RiverpodDaoMixin {
  RiverpodDao(super.attachedDatabase);

  Future<CredentialsState?> getSettings() async {
    final settingsRow = await managers.riverpodStorage
        .filter((f) => f.key(Credentials.persistKey))
        .getSingleOrNull();

    if (settingsRow != null) {
      return CredentialsState.fromJson(jsonDecode(settingsRow.data));
    }

    return null;
  }
}
