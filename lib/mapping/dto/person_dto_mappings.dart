import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';

extension PersonDtoMappings on PersonDto {
  PeopleCompanion toPeopleCompanion() {
    return PeopleCompanion.insert(
      id: Value(id!),
      name: name!,
      primaryColor: Value.absentIfNull(primaryColor),
      secondaryColor: Value.absentIfNull(secondaryColor),
      description: Value.absentIfNull(description),
      aliases: Value.absentIfNull(aliases),
    );
  }
}
