import 'package:kover/api/openapi.swagger.dart';

class BookmarkSyncOperations(final Openapi _client) {
  /// Get all bookmarks for the user
  Future<List<BookmarkDto>> getAllBookmarks() async {
    final res = await _client.apiReaderAllBookmarksPost(
      body: const SeriesFilterV2Dto(
        id: 0,
        limitTo: 0,
        combination: FilterCombination.and,
        sortOptions: SeriesSortOptionDto(
          sortField: SeriesSortField.sortname,
          isAscending: true,
        ),
        statements: [],
      ),
    );
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load all bookmarks: ${res.error}');
    }
    return res.body!;
  }

  /// Add bookmark for [dto]
  Future<void> add(BookmarkDto dto) async {
    final res = await _client.apiReaderBookmarkPost(body: dto);
    if (!res.isSuccessful) {
      throw Exception('Failed to add bookmark: ${res.error}');
    }
  }

  /// Remove bookmark for [dto]
  Future<void> remove(BookmarkDto dto) async {
    final res = await _client.apiReaderUnbookmarkPost(body: dto);
    if (!res.isSuccessful) {
      throw Exception('Failed to remove bookmark: ${res.error}');
    }
  }
}
