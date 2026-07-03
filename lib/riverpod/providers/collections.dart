import 'package:kover/models/collection_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/repository/collections_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collections.g.dart';

@riverpod
Stream<List<CollectionModel>> collections(Ref ref) {
  final repository = ref.watch(collectionsRepositoryProvider);
  return repository.watchCollections();
}

@riverpod
Stream<CollectionModel> collection(Ref ref, {required int collectionId}) {
  final repository = ref.watch(collectionsRepositoryProvider);
  return repository.watchCollection(collectionId).distinct();
}

@riverpod
Stream<ImageModel?> collectionCover(Ref ref, {required int collectionId}) {
  final repository = ref.watch(collectionsRepositoryProvider);
  return repository.watchCollectionCover(collectionId);
}
