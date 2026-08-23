import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/enums/filter_type.dart';
import 'package:kover/database/app_database.dart';

part 'smart_filter_model.freezed.dart';

@freezed
sealed class SmartFilterModel with _$SmartFilterModel {
  const factory SmartFilterModel({
    required int id,
    required String name,
    required FilterType type,
  }) = _SmartFilterModel;

  factory fromDatabaseModel(SmartFilter row) {
    return SmartFilterModel(
      id: row.id,
      name: row.name!,
      type: row.type,
    );
  }
}
