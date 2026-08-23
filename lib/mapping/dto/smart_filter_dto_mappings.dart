import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/filter_type.dart';

extension SmartFilterDtoMappings on SmartFilterDto {
  SmartFiltersCompanion toSmartFiltersCompanion() {
    return SmartFiltersCompanion.insert(
      id: Value(id!),
      name: Value(name),
      filter: Value(filter),
      type: FilterType.fromDtoFilterType(entityType),
    );
  }
}
