import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/reading_list_dto_mappings.dart';
import 'package:kover/utils/logging.dart';

class ReadingListSyncOperations {
  final Openapi _client;
  final String _apiKey;

  const ReadingListSyncOperations({
    required this._client,
    required this._apiKey,
  });

  /// Fetch all collections
  Future<Iterable<ReadingListsCompanion>> getReadingLists() async {
    final res = await _client.apiReadingListAllPost(
      body: const ReadingListFilterDto(
        id: 0,
        combination: .and,
        entityType: .readinglist,
        limitTo: 0,
        sortOptions: ReadingListSortOptionDto(
          sortField: .title,
          isAscending: true,
        ),
        statements: [
          ReadingListFilterStatementDto(
            comparison: .equal,
            field: .title,
            value: '',
          ),
        ],
      ),
    );

    if (!res.isSuccessful) {
      throw Exception('Failed to fetch reading lists: ${res.error}');
    }

    return res.body?.map(
          (readingList) => readingList.toReadingListCompanion(),
        ) ??
        [];
  }

  /// Fetch all series in collection [readingListId]
  Future<Iterable<ReadingListsChaptersCompanion>> getReadingListChapters(
    int readingListId,
  ) async {
    final res = await _client.apiReadingListItemsGet(
      readingListId: readingListId,
    );

    if (!res.isSuccessful) {
      throw Exception('Failed to fetch collection series: ${res.error}');
    }

    return res.body?.map(
          (item) => ReadingListsChaptersCompanion.insert(
            readingListId: readingListId,
            chapterId: item.chapterId!,
            order: item.order!,
          ),
        ) ??
        [];
  }

  /// Fetch collection cover for [readingListId]
  Future<ReadingListCoversCompanion?> getReadingListCover(
    int readingListId,
  ) async {
    final res = await _client.apiImageReadinglistCoverGet(
      readingListId: readingListId,
      apiKey: _apiKey,
    );

    if (!res.isSuccessful) {
      log.error(
        'failed to fetch reading list cover',
        error: res.error,
        attributes: {
          'reading_list_id': .int(readingListId),
          'status_code': .int(res.statusCode),
        },
      );
      return null;
    }

    return ReadingListCoversCompanion.insert(
      readingListId: Value(readingListId),
      image: res.bodyBytes,
    );
  }
}
