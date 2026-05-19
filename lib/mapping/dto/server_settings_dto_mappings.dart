import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/utils/data_constants.dart';

extension ServerSettingDtoMappings on ServerSettingDto {
  ServerSettingsCompanion toServerSettingsCompanion() {
    return ServerSettingsCompanion(
      key: const Value(DataConstants.serverSettingsKey),
      installVersion: Value.absentIfNull(installVersion),
      onDeckProgressDays: Value(onDeckProgressDays!),
      onDeckUpdateDays: Value(onDeckUpdateDays!),
    );
  }
}
