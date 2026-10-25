import 'package:kover/api/openapi.swagger.dart';

class AnnotationSyncOperations(final Openapi _client) {
  /// Get all annotations visible to the user.
  Future<List<AnnotationDto>> getAllAnnotations() async {
    final res = await _client.apiAnnotationAllFilteredPost(
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
      throw Exception('Failed to load all annotations: ${res.error}');
    }
    return res.body!;
  }

  /// Get all annotations of [chapterId] visible to the user.
  Future<List<AnnotationDto>> getChapterAnnotations(int chapterId) async {
    final res = await _client.apiAnnotationAllGet(chapterId: chapterId);
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load annotations: ${res.error}');
    }
    return res.body!;
  }

  /// Get the annotation with the server id [annotationId], or null when the
  /// server doesn't have it.
  Future<AnnotationDto?> get(int annotationId) async {
    final res = await _client.apiAnnotationAnnotationIdGet(
      annotationId: annotationId,
    );
    if (res.statusCode == 404) return null;
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load annotation: ${res.error}');
    }
    return res.body!;
  }

  /// Create [annotation] on the server and return the server's copy.
  Future<AnnotationDto> create(AnnotationDto annotation) async {
    final res = await _client.apiAnnotationCreatePost(body: annotation);
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to create annotation: ${res.error}');
    }
    return res.body!;
  }

  /// Update the comment, highlight slot and spoiler flag of [annotation] on
  /// the server and return the server's copy.
  Future<AnnotationDto> update(AnnotationDto annotation) async {
    final res = await _client.apiAnnotationUpdatePost(body: annotation);
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to update annotation: ${res.error}');
    }
    return res.body!;
  }

  /// Delete the annotation with the server id [annotationId].
  Future<void> delete(int annotationId) async {
    final res = await _client.apiAnnotationDelete(annotationId: annotationId);
    if (!res.isSuccessful) {
      throw Exception('Failed to delete annotation: ${res.error}');
    }
  }

  /// Get the highlight slots from the user preferences.
  Future<List<HighlightSlot>> getHighlightSlots() async {
    final res = await _client.apiUsersGetPreferencesGet();
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load user preferences: ${res.error}');
    }
    return res.body!.bookReaderHighlightSlots;
  }
}
