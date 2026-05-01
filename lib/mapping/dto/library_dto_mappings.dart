import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart' hide LibraryType;
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/library_type.dart';

extension LibraryDtoMappings on LibraryDto {
  LibrariesCompanion toLibrariesCompanion() {
    return LibrariesCompanion(
      id: Value(id!),
      name: Value(name!),
      type: Value(LibraryType.fromDtoType(type!)),
    );
  }
}
