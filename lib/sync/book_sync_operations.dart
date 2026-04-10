import 'dart:convert';

import 'package:csslib/visitor.dart';
import 'package:drift/drift.dart' hide Expression;
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:csslib/parser.dart' as css;
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/page_content.dart';
import 'package:kover/utils/extensions/element.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:kover/utils/logging.dart';

class BookSyncOperations {
  final Openapi _client;
  final String _apiKey;

  const BookSyncOperations({required Openapi client, required String apiKey})
    : _client = client,
      _apiKey = apiKey;

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

  /// Get preprocessed epub page [page] for [chapterId]
  Future<PageContent> getPageContent({
    required int chapterId,
    required int page,
  }) async {
    final frag = await _getPreprocessedPage(chapterId: chapterId, page: page);
    final styles = <String, Map<String, String>>{};
    final fonts = <String, List<Uint8List>>{};

    for (final stylesElement in frag.querySelectorAll('style')) {
      styles.addAll(_parseStyles(stylesElement.innerHtml));
      fonts.addAll(await _parseFonts(stylesElement.innerHtml));
      stylesElement.remove();
    }

    styles['a'] = {'text-decoration': 'none'};

    return PageContent(root: frag, styles: styles, fonts: fonts);
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
        n.attributes[HtmlConstants.scrollIdAttribute] = n.scrollId;

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

            final svgParent = n.parent;
            if (svgParent != null && svgParent.localName == 'svg') {
              svgParent.replaceWith(imgTag);
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
    } catch (e) {
      log.e('failed to fetch page image', error: e);
    }

    return null;
  }

  Map<String, Map<String, String>> _parseStyles(String cssString) {
    final sheet = css.parse(cssString);
    final visitor = _CssToMapVisitor();
    sheet.visit(visitor);

    return visitor.resultMap;
  }

  Future<Map<String, List<Uint8List>>> _parseFonts(String cssString) async {
    final sheet = css.parse(cssString);
    final visitor = _FontFaceVisitor();
    sheet.visit(visitor);

    final res = <String, List<Uint8List>>{};
    for (final entry in visitor.fontMap.entries) {
      for (final url in entry.value) {
        log.d('Found Font: ${entry.key} at $url');
        final data = await _fetchData(url);
        if (data == null || data.bytes.isEmpty) continue;
        res.putIfAbsent(entry.key, () => []).add(data.bytes);
      }
    }

    return res;
  }

  String _resolveUrl(String url) {
    if (url.startsWith('//')) {
      return '${_client.client.baseUrl.scheme}:$url';
    }
    return url;
  }
}

class _FontFaceVisitor extends Visitor {
  final Map<String, List<String>> fontMap = {};

  String? _currentFamily;
  List<String> _currentUrls = [];

  @override
  void visitFontFaceDirective(FontFaceDirective node) {
    _currentFamily = null;
    _currentUrls = [];

    super.visitFontFaceDirective(node);

    if (_currentFamily != null && _currentUrls.isNotEmpty) {
      fontMap.putIfAbsent(_currentFamily!, () => []).addAll(_currentUrls);
    }
  }

  @override
  void visitDeclaration(Declaration node) {
    final property = node.property.toLowerCase();

    final expr = node.expression;
    if (expr == null) return;

    if (property == 'font-family') {
      final term = expr is Expressions ? expr.expressions.firstOrNull : expr;
      if (term is LiteralTerm) {
        final v = term.value;
        _currentFamily = v is Identifier ? v.name : v as String;
      }
    } else if (property == 'src') {
      _currentUrls = _extractUrls(expr);
    }

    super.visitDeclaration(node);
  }

  List<String> _extractUrls(Expression expr) {
    if (expr is! Expressions) return [];
    return expr.expressions
        .whereType<UriTerm>()
        .map((t) => t.value as String)
        .toList();
  }
}

class _CssToMapVisitor extends Visitor {
  final Map<String, Map<String, String>> resultMap = {};
  Set<String> currentSelectors = {};

  @override
  void visitRuleSet(RuleSet node) {
    final selectorGroup = node.selectorGroup;
    if (selectorGroup == null) return;

    currentSelectors = {};

    // Iterate through every selector in the comma-separated list
    for (var selector in selectorGroup.selectors) {
      final sequences = selector.simpleSelectorSequences;
      if (sequences.isEmpty) continue;

      // Collect any trailing pseudo-element suffix (e.g. "::first-letter").
      // These appear as the last sequence(s) with no combinator.
      final pseudoSuffix = StringBuffer();
      var baseIndex = sequences.length - 1;
      while (baseIndex >= 0 &&
          sequences[baseIndex].simpleSelector is PseudoElementSelector) {
        final pseudo =
            sequences[baseIndex].simpleSelector as PseudoElementSelector;
        // Prepend so multiple pseudos come out in source order
        pseudoSuffix.write('::${pseudo.name}');
        baseIndex--;
      }

      if (baseIndex < 0) continue;

      // The base is the rightmost non-pseudo-element selector.
      // We ignore ancestor/combinator parts (flat, specificity-free).
      final baseSimple = sequences[baseIndex].simpleSelector;
      String? base;

      if (baseSimple is ClassSelector) {
        base = '.${baseSimple.name}';
      } else if (baseSimple is ElementSelector) {
        base = baseSimple.name;
      }

      if (base != null) {
        final name = '$base$pseudoSuffix';
        currentSelectors.add(name);
        resultMap.putIfAbsent(name, () => {});
      }
    }

    super.visitRuleSet(node);
  }

  @override
  void visitDeclaration(Declaration node) {
    final expr = node.expression;
    if (expr == null) return;
    final printer = CssPrinter();
    expr.visit(printer);
    final value = printer.toString();
    for (final selector in currentSelectors) {
      resultMap[selector]![node.property] = value;
    }
    super.visitDeclaration(node);
  }
}
