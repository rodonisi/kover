import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/dashboard_stream_type.dart';

extension DashboardStreamDtoMappings on DashboardStreamDto {
  DashboardCompanion toDashboardCompanion() {
    return DashboardCompanion.insert(
      id: Value(id!),
      name: Value.absentIfNull(name),
      order: order!,
      visible: visible!,
      type: _toDashboardSectionType(),
      smartFilterId: Value.absentIfNull(smartFilterId),
    );
  }

  DashboardSectionType _toDashboardSectionType() {
    return switch (streamType) {
      .ondeck => .onDeck,
      .recentlyupdated => .recentlyUpdated,
      .newlyadded => .newlyAdded,
      .smartfilter => .smartFilter,
      _ => .unknown,
    };
  }
}
