import 'package:drift/drift.dart';
import 'package:kover/models/enums/format.dart';

final _whitespaceRegExp = RegExp(r'\s+');

/// Matches chapter [format] values whose pages are single images and therefore
/// support bookmarks.
Expression<bool> isBookmarkableChapterFormat(Expression<String> format) =>
    format.isIn([Format.image.name, Format.archive.name]);

/// Build an OR of [columns] each containing [query].
Expression<bool> containsAny(
  String query,
  Iterable<GeneratedColumn<String>> columns,
) {
  return columns
      .map((column) => column.contains(query))
      .reduce((a, b) => a | b);
}

/// Build an AND expression across whitespace-separated tokens of [query].
Expression<bool> matchesAllTokens(
  String query,
  Expression<bool> Function(String token) matcher,
) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const Constant(true);
  return trimmed.split(_whitespaceRegExp).map(matcher).reduce((a, b) => a & b);
}

/// Match [query] where at least one token matches [itemMatcher] and all tokens
/// match either [itemMatcher] or [parentMatcher].
Expression<bool> matchesTokensWithParent(
  String query,
  Expression<bool> Function(String token) itemMatcher,
  Expression<bool> Function(String token) parentMatcher,
) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const Constant(false);
  final tokens = trimmed.split(_whitespaceRegExp);
  if (tokens.length == 1) return itemMatcher(tokens.single);
  final item = [for (final t in tokens) itemMatcher(t)];
  final both = [
    for (var i = 0; i < tokens.length; i++) item[i] | parentMatcher(tokens[i]),
  ];
  return both.reduce((a, b) => a & b) & item.reduce((a, b) => a | b);
}

/// Rank full-title (`0`), partial-title (`1`), and metadata-only (`2`) matches.
Expression<int> titleMatchRank(
  String query,
  Iterable<GeneratedColumn<String>> columns,
) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const Constant(0);
  final tokens = trimmed.split(_whitespaceRegExp);
  final matched = [for (final t in tokens) containsAny(t, columns)];
  return CaseWhenExpression<int>(
    cases: [
      CaseWhen(matched.reduce((a, b) => a & b), then: const Constant(0)),
      CaseWhen(matched.reduce((a, b) => a | b), then: const Constant(1)),
    ],
    orElse: const Constant(2),
  );
}

/// Progress ratio (pages read / total pages) as a double expression.
Expression<double> progressRatio(
  Expression<int> pagesReadSum,
  Expression<int> totalPages,
) {
  return pagesReadSum.cast<double>() / totalPages.cast<double>();
}

/// Whether a set of [pagesReadSum] is unread against [totalPages].
Expression<bool> hasUnreadProgress(
  Expression<int> pagesReadSum,
  Expression<int> totalPages,
) {
  return pagesReadSum.isNull() | pagesReadSum.isSmallerThan(totalPages);
}
