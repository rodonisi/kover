import 'package:kover/api/openapi.swagger.dart';

class AnnotationSyncOperations(final Openapi _client) {
  /// Get all annotations visible to the current user.
  Future<List<AnnotationDto>> getAllAnnotations() async {
    final res = await _client.apiAnnotationAllFilteredPost(
      pageSize: 0,
      body: const AnnotationFilterDto(
        id: 0,
        limitTo: 0,
        combination: FilterCombination.and,
        sortOptions: AnnotationSortOptionDto(
          sortField: AnnotationSortField.created,
          isAscending: true,
        ),
        statements: [],
      ),
    );
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load annotations: ${res.error}');
    }
    return res.body!;
  }

  Future<UserDto> getCurrentUser() async {
    final res = await _client.apiAccountGet();
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load current user: ${res.error}');
    }
    return res.body!;
  }

  /// Get all annotations for [chapterId].
  Future<List<AnnotationDto>> getChapterAnnotations(int chapterId) async {
    final res = await _client.apiAnnotationAllGet(chapterId: chapterId);
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load chapter annotations: ${res.error}');
    }
    return res.body!;
  }

  /// Create [dto] and return the server representation.
  Future<AnnotationDto> create(AnnotationDto dto) async {
    final res = await _client.apiAnnotationCreatePost(body: dto);
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to create annotation: ${res.error}');
    }
    return res.body!;
  }

  /// Update the modifiable fields of [dto] and return the server
  /// representation.
  Future<AnnotationDto> update(AnnotationDto dto) async {
    final res = await _client.apiAnnotationUpdatePost(body: dto);
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to update annotation: ${res.error}');
    }
    return res.body!;
  }

  /// Delete the annotation with [annotationId].
  Future<void> remove(int annotationId) async {
    final res = await _client.apiAnnotationDelete(annotationId: annotationId);
    if (!res.isSuccessful) {
      throw Exception('Failed to delete annotation: ${res.error}');
    }
  }
}
