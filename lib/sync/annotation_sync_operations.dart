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

  /// Get the highlight slots from the user preferences.
  Future<List<HighlightSlot>> getHighlightSlots() async {
    final res = await _client.apiUsersGetPreferencesGet();
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load user preferences: ${res.error}');
    }
    return res.body!.bookReaderHighlightSlots;
  }
}
