import 'package:kover/database/app_database.dart';
import 'package:kover/database/converters/page_content_converter.dart';
import 'package:kover/models/book_chapter_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/models/page_content.dart';
import 'package:kover/models/pdf_model.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/database.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:kover/utils/chunked_fetch.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_repository.g.dart';

@Riverpod(keepAlive: true)
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

  /// Get [page] of [chapterId] as an epub page. Returns the stored page if
  /// [chapterId] is downloaded, otherwise fetches it from the server. Font
  /// bytes are not resolved here; the font manager loads them on demand.
  Future<PageContent> getEpubPage({
    required int chapterId,
    required int page,
  }) async {
    final isDownloaded = await _db.downloadDao
        .isChapterDownloaded(chapterId: chapterId)
        .getSingle();

    if (isDownloaded) {
      log.debug(
        'using downloaded page for chapter',
        attributes: {
          'chapter_id': chapterId,
          'page': page,
        },
      );
      final p = await _db.downloadDao
          .getPage(chapterId: chapterId, page: page)
          .getSingle();
      return pageContentConverter.fromSql(p.data);
    }

    return _client.getPageContent(
      chapterId: chapterId,
      page: page,
    );
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
      log.debug(
        'using downloaded page for chapter',
        attributes: {
          'chapter_id': chapterId,
          'page': page,
        },
      );
      final p = await _db.downloadDao
          .getPage(chapterId: chapterId, page: page)
          .getSingle();

      return ImageModel(data: p.data);
    }

    return ImageModel(
      data: await _client.getImagePage(chapterId: chapterId, page: page),
    );
  }

  Future<PdfModel> getPdf({
    required int chapterId,
  }) async {
    if (await _db.downloadDao
        .isChapterDownloaded(chapterId: chapterId)
        .getSingle()) {
      log.debug(
        'using downloaded PDF for chapter',
        attributes: {
          'chapter_id': chapterId,
        },
      );
      final p = await _db.downloadDao
          .getPage(chapterId: chapterId, page: 0)
          .getSingle();

      return PdfModel(data: p.data);
    }

    return PdfModel(
      data: await _client.getPdf(chapterId: chapterId),
    );
  }

  /// Refresh the table of contents for [chapterId] by fetching it from the
  /// server and updating the local database.
  Future<void> refreshChapterToc({required int chapterId}) async {
    final entries = await _client.getBookChapters(chapterId);
    await _db.bookDao.upsertTocBatch(entries);
  }

  /// Fetch the table of contents for all chapters that are missing it.
  Future<void> fetchMissingChaptersTocs() async {
    final chapters = await _db.bookDao.getMissingTocChapterIds();

    await chunkedFetch(
      items: chapters,
      fetchCallback: (id) => _client.getBookChapters(id),
      upsertCallback: (batch) async {
        final flat = batch.expand((e) => e).toList();
        return _db.bookDao.upsertTocBatch(flat);
      },
    );
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
