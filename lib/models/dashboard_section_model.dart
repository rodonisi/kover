import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';

part 'dashboard_section_model.freezed.dart';

@freezed
sealed class DashboardSectionModel with _$DashboardSectionModel {
  const factory onDeck() = _OnDeckDashboardSectionModel;

  const factory recentlyUpdated() = _RecentlyUpdatedDashboardSectionModel;

  const factory newlyAdded() = _NewlyAddedDashboardSectionModel;

  const factory smartFilter({
    required int id,
  }) = _SmartFilterDashboardSectionModel;

  factory fromDatabaseModel(DashboardData row) {
    return switch (row.type) {
      .onDeck => const DashboardSectionModel.onDeck(),
      .recentlyUpdated => const DashboardSectionModel.recentlyUpdated(),
      .newlyAdded => const DashboardSectionModel.newlyAdded(),
      .smartFilter => DashboardSectionModel.smartFilter(id: row.smartFilterId!),
      _ => throw Exception('Unsupported dashboard section type ${row.type}'),
    };
  }
}
