import 'package:kover/models/library_model.dart';
import 'package:kover/riverpod/repository/libraries_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library.g.dart';

@riverpod
Stream<LibraryModel> library(Ref ref, {required int libraryId}) {
  final repo = ref.watch(librariesRepositoryProvider);
  return repo.watchLibrary(libraryId).distinct();
}

@riverpod
Stream<List<LibraryModel>> libraries(Ref ref) {
  final repo = ref.watch(librariesRepositoryProvider);
  return repo.watchLibraries().distinct();
}
