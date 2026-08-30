import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/font_provider.dart' as provider_enum;

extension EpubFontDtoMappings on EpubFontDto {
  ServerFontsCompanion toServerFontsCompanion() {
    return ServerFontsCompanion(
      id: Value(id!),
      family: Value(family!),
      name: Value.absentIfNull(name),
      provider: Value(provider_enum.FontProvider.fromDto(provider!)),
      fileName: Value.absentIfNull(fileName),
      style: Value.absentIfNull(style),
      weight: Value.absentIfNull(weight),
    );
  }
}
