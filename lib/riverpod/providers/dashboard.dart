import 'package:flutter/foundation.dart';
import 'package:kover/models/dashboard_section_model.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard.g.dart';

@riverpod
Stream<List<DashboardSectionModel>> dashboardSections(Ref ref) {
  final repo = ref.watch(librariesRepositoryProvider);
  return repo.watchDashboard().distinct(listEquals);
}
