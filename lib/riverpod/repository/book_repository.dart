import 'package:fluvita/database/app_database.dart';
import 'package:fluvita/database/converters/page_content_converter.dart';
import 'package:fluvita/models/book_chapter_model.dart';
import 'package:fluvita/models/image_model.dart';
import 'package:fluvita/models/page_content.dart';
import 'package:fluvita/riverpod/providers/client.dart';
import 'package:fluvita/riverpod/providers/settings/settings.dart';
import 'package:fluvita/riverpod/repository/database.dart';
import 'package:fluvita/sync/book_sync_operations.dart';
import 'package:fluvita/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_repository.g.dart';

@riverpod
BookRepository bookRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final restClient = ref.watch(restClientProvider);
  final apiKey = ref.watch(apiKeyProvider);

  final client = BookSyncOperations(client: restClient, apiKey: apiKey!);
  return BookRepository(db, client);
}

class BookRepository {
  final AppDatabase _db;
  final BookSyncOperations _client;

  BookRepository(this._db, this._client);

  /// Watch TOC for [chapterId]
  Stream<List<BookChapterModel>> watchBookChapters(int chapterId) {
    return _db.bookDao.watchToc(chapterId).map(_buildTree);
  }

  /// Get [page] of [chapterId] as an epub page. Returns the stored page if [chapterId] is
  /// downloaded, otherwise fetches it from the server.
  Future<PageContent> getEpubPage({
    required int chapterId,
    required int page,
  }) async {
    if (await _db.downloadDao
        .isChapterDownloaded(chapterId: chapterId)
        .getSingle()) {
      log.d('using downloaded page for chapter $chapterId, page $page');
      final p = await _db.downloadDao
          .getPage(chapterId: chapterId, page: page)
          .getSingle();

      return pageContentConverter.fromSql(p.data);
    }

    return await _client.getPageContent(chapterId: chapterId, page: page);
  }

  /// Get [page] of [chapterId] as an image page. Returns the stored page if [chapterId] is
  /// downloaded, otherwise fetches it from the server.
  Future<ImageModel> getImagePage({
    required int chapterId,
    required int page,
  }) async {
    if (await _db.downloadDao
        .isChapterDownloaded(chapterId: chapterId)
        .getSingle()) {
      log.d('using downloaded page for chapter $chapterId, page $page');
      final p = await _db.downloadDao
          .getPage(chapterId: chapterId, page: page)
          .getSingle();

      return ImageModel(data: p.data);
    }

    return ImageModel(
      data: await _client.getImagePage(chapterId: chapterId, page: page),
    );
  }

  /// Fetch the table of contents for all chapters that are missing it.
  Future<void> fetchMissingChaptersTocs() async {
    final chapters = await _db.bookDao.getMissingChapterIds();
    for (final id in chapters) {
      final entries = await _client.getBookChapters(id);
      await _db.bookDao.upsertToc(id, entries);
    }
  }

  static List<BookChapterModel> _buildTree(
    List<BookChaptersTableData> rows,
  ) {
    List<BookChapterModel> build(int? parentPage) {
      return rows
          .where(
            (r) => r.parentPage == parentPage && r.page != parentPage,
          )
          .map(
            (r) => BookChapterModel(
              title: r.title,
              page: r.page,
              children: build(r.page),
            ),
          )
          .toList();
    }

    return build(null);
  }
}
