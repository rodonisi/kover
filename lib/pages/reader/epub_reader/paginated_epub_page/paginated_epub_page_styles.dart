import 'package:kover/pages/reader/epub_reader/paginated_epub_page/paginated_epub_page_settings.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';

/// Merges stylesheet layers. Later layers override earlier declarations while
/// preserving the selector order in which they first appeared.
Map<String, Map<String, String>> mergeStyles(
  Iterable<Map<String, Map<String, String>>> layers,
) {
  final result = <String, Map<String, String>>{};

  for (final layer in layers) {
    for (final entry in layer.entries) {
      result.putIfAbsent(entry.key, () => {}).addAll(entry.value);
    }
  }

  return result;
}

/// Builds the stylesheet derived from reader settings.
///
/// These styles are applied as an additional stylesheet on top of the document
/// styles, so they win over the book's own rules.
Map<String, Map<String, String>> settingsStyles(
  PaginatedEpubPageSettings settings,
) {
  final global = <String, String>{
    if (settings.fontFamily case final family?)
      'font-family': '"${family.replaceAll('"', "'")}"',
    if (settings.removeParagraphIndent) 'text-indent': '0',
  };

  return {
    'p': {
      'margin-bottom': '${settings.paragraphSpacing}em',
      'text-align': settings.textAlignment.cssValue,
    },
    if (global.isNotEmpty) '*': global,
  };
}

extension on EpubTextAlignment {
  String get cssValue => switch (this) {
    .left => 'left',
    .right => 'right',
    .center => 'center',
    .justify => 'justify',
  };
}
