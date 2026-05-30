import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart' hide LibraryType;
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/library_type.dart';
import 'package:kover/utils/extensions/date_time.dart';

extension LibraryDtoMappings on LibraryDto {
  LibrariesCompanion toLibrariesCompanion() {
    return LibrariesCompanion.insert(
      id: Value(id!),
      name: name!,
      type: LibraryType.fromDtoType(type!),
      includeInDashboard: Value.absentIfNull(includeInDashboard),
      includeInRecommended: Value.absentIfNull(includeInRecommended),
      includeInSearch: Value.absentIfNull(includeInSearch),
      defaultLanguage: Value.absentIfNull(defaultLanguage),
      lastScanned: Value.absentIfNull(lastScanned?.normalizeUtc()),
    );
  }
}
