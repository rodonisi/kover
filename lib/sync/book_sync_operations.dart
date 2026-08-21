import 'dart:convert';

import 'package:drift/drift.dart' hide Expression;
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/page_content.dart';
import 'package:kover/utils/epub_font_parser.dart';
import 'package:kover/utils/logging.dart';

class BookSyncOperations {
  final Openapi _client;
  final String _apiKey;

  const BookSyncOperations({
    required this._client,
    required this._apiKey,
  });

  /// Get the book chapter to page mapping (aka TOC) for [chapterId].
  Future<Iterable<BookChaptersTableCompanion>> getBookChapters(
    int chapterId,
  ) async {
    final res = await _client.apiBookChapterIdChaptersGet(
      chapterId: chapterId,
    );
    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load book chapters: ${res.error}');
    }
    return _flattenChapters(chapterId, res.body!, null);
  }

  /// Get image [page] for [chapterId]
  Future<Uint8List> getImagePage({
    required int chapterId,
    required int page,
  }) async {
    final res = await _client.apiReaderImageGet(
      chapterId: chapterId,
      page: page,
      apiKey: _apiKey,
    );

    if (!res.isSuccessful) {
      throw Exception('Failed to load reader image: ${res.error}');
    }

    return res.bodyBytes;
  }

  /// Get PDF for [chapterId]
  Future<Uint8List> getPdf({required int chapterId}) async {
    final res = await _client.apiReaderPdfGet(
      chapterId: chapterId,
      apiKey: _apiKey,
    );

    if (!res.isSuccessful) {
      throw Exception('Failed to load PDF: ${res.error}');
    }

    return res.bodyBytes;
  }

  /// Get preprocessed epub page [page] for [chapterId] with all remote images
  /// embedded as base64 data URIs.
  Future<PageContent> getPageContent({
    required int chapterId,
    required int page,
  }) async {
    final frag = await _getPreprocessedPage(chapterId: chapterId, page: page);
    final styles = <String, Map<String, String>>{};

    styles['a'] = {'text-decoration': 'none'};

    final fonts = EpubFontParser.parseStyles(frag.querySelectorAll('style'));

    return PageContent(root: frag, styles: styles, fonts: fonts);
  }

  /// Fetches the raw font file at [url].
  Future<({Uint8List bytes, String mimeType})?> getFontBytes(String url) {
    return _fetchData(url);
  }

  static Iterable<BookChaptersTableCompanion> _flattenChapters(
    int chapterId,
    List<BookChapterItem> items,
    int? parentPage,
  ) sync* {
    for (final item in items) {
      yield BookChaptersTableCompanion(
        chapterId: Value(chapterId),
        title: Value(item.title!),
        page: Value(item.page!),
        parentPage: Value(parentPage),
      );
      if (item.children != null && item.children!.isNotEmpty) {
        yield* _flattenChapters(chapterId, item.children!, item.page!);
      }
    }
  }

  Future<String> _getRawBookPage({
    required int chapterId,
    required int page,
  }) async {
    final res = await _client.apiBookChapterIdBookPageGet(
      chapterId: chapterId,
      page: page,
    );

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load book page: ${res.error}');
    }

    return res.body!;
  }

  Future<DocumentFragment> _getPreprocessedPage({
    required int chapterId,
    required int page,
  }) async {
    Future<void> walk(Node node) async {
      for (var n in node.children) {
        if (n.localName == 'img') {
          final src = '${n.attributes['src']}';
          if (src.isNotEmpty) {
            final imageData = await _fetchData(src);
            if (imageData != null) {
              final base64img = base64Encode(imageData.bytes);
              n.attributes['src'] =
                  'data:${imageData.mimeType};base64,$base64img';
            }
          }
        }

        if (n.localName == 'image') {
          final attr = n.attributes.entries.where((entry) {
            final key = entry.key;
            return key is AttributeName && key.name == 'href';
          }).first;

          final src = attr.value;
          final imageData = await _fetchData(src);
          if (imageData != null) {
            final base64img = base64Encode(
              imageData.bytes,
            ).replaceAll(RegExp(r'\s+'), '');

            // Replace <svg><image></image></svg> with <img> with embedded base64
            final imgTag = Element.tag('img');
            imgTag.attributes['src'] =
                'data:${imageData.mimeType};base64,$base64img';

            // Copy over width/height if present
            if (n.attributes['width'] != null) {
              imgTag.attributes['width'] = n.attributes['width']!;
            }
            if (n.attributes['height'] != null) {
              imgTag.attributes['height'] = n.attributes['height']!;
            }
            if (n.attributes.containsKey('style')) {
              imgTag.attributes['style'] = n.attributes['style']!;
            }
            if (n.attributes.containsKey('class')) {
              imgTag.attributes['class'] = n.attributes['class']!;
            }

            final svgParent = n.parent;
            if (svgParent != null && svgParent.localName == 'svg') {
              final newParent = Element.tag('div');

              if (svgParent.attributes.containsKey('class')) {
                newParent.attributes['class'] = svgParent.attributes['class']!;
              }
              if (svgParent.attributes.containsKey('style')) {
                newParent.attributes['style'] = svgParent.attributes['style']!;
              }
              newParent.append(imgTag);
              svgParent.replaceWith(newParent);
            } else {
              n.replaceWith(imgTag);
            }
          }
        }

        await walk(n);
      }
    }

    final html = await _getRawBookPage(chapterId: chapterId, page: page);
    final doc = parseFragment(html);
    for (var node in doc.nodes) {
      await walk(node);
    }

    return doc;
  }

  Future<({Uint8List bytes, String mimeType})?> _fetchData(
    String url,
  ) async {
    try {
      final res = await _client.client.get(
        Uri.parse(_resolveUrl(url)),
      );

      if (res.isSuccessful && res.bodyBytes.isNotEmpty) {
        final mimeType = res.headers['content-type'] ?? 'image/png';
        return (bytes: res.bodyBytes, mimeType: mimeType);
      }
    } catch (e, stacktrace) {
      log.error(
        'failed to fetch EPUB page image',
        error: e,
        stacktrace: stacktrace,
      );
    }

    return null;
  }

  String _resolveUrl(String url) {
    if (url.startsWith('//')) {
      return '${_client.client.baseUrl.scheme}:$url';
    }
    return url;
  }
}
