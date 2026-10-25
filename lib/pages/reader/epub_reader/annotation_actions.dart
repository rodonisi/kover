import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/annotation_model.dart';
import 'package:kover/pages/reader/epub_reader/annotation_editor.dart';
import 'package:kover/pages/reader/epub_reader/epub_selection.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/reader.dart';
import 'package:kover/riverpod/repository/annotation_repository.dart';
import 'package:kover/riverpod/repository/download_repository.dart';
import 'package:kover/utils/extensions/element.dart';
import 'package:kover/utils/html_constants.dart';
import 'package:kover/utils/logging.dart';
import 'package:material_ui/material_ui.dart';

final _whitespace = RegExp(r'\s+');

/// Collapses whitespace like Kavita does before looking the selected text up
/// in the page, and drops the placeholders of inline widgets.
String _collapse(String text) =>
    text.replaceAll('\uFFFC', '').replaceAll(_whitespace, ' ').trim();

/// Creates a highlight from the [selection] in [page] of [chapterId]: asks
/// for its note and color, creates it on the server and shows the page again
/// with it. Returns whether it was created.
///
/// Like Kavita's web reader, the highlight is located by the elements where
/// the selection starts and ends and by its text; Kover uses the text blocks
/// [tracker] reports.
Future<bool> createHighlight(
  BuildContext context,
  WidgetRef ref, {
  required EpubSelectionTracker tracker,
  required String selection,
  required int seriesId,
  required int chapterId,
  required int? readingListId,
  required int page,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  final selectedText = _collapse(selection);
  final blocks = tracker.selectedBlocks;
  final start = blocks.isEmpty
      ? null
      : tracker.elementOf(blocks.first.scrollId);
  final end = blocks.isEmpty ? null : tracker.elementOf(blocks.last.scrollId);
  final xPath = start?.kavitaXPath();
  final endingXPath = end?.kavitaXPath();
  if (selectedText.isEmpty || xPath == null || endingXPath == null) {
    messenger.showSnackBar(SnackBar(content: Text(l.cannotHighlightHere)));
    return false;
  }

  final draft = await showAnnotationEditor(
    context,
    ref,
    selectedText: selectedText,
  );
  if (draft == null) return false;

  final AnnotationModel created;
  try {
    final reader = await container.read(
      readerProvider(
        seriesId: seriesId,
        chapterId: chapterId,
        readingListId: readingListId,
      ).future,
    );
    final user = await container.read(currentUserProvider.future);

    created = await container
        .read(annotationRepositoryProvider)
        .createAnnotation(
          seriesId: seriesId,
          volumeId: reader.volumeId,
          chapterId: chapterId,
          page: page,
          ownerUserId: user.id,
          xPath: xPath,
          endingXPath: endingXPath,
          selectedText: selectedText,
          context: _collapse(start!.text),
          comment: draft.comment,
          selectedSlotIndex: draft.selectedSlotIndex,
          containsSpoiler: draft.containsSpoiler,
        );
  } catch (e) {
    log.warning('could not create annotation', attributes: {'error': e});
    messenger.showSnackBar(SnackBar(content: Text(l.highlightNotCreated)));
    return false;
  }

  final placed = await refreshAnnotatedPage(
    container,
    chapterId: chapterId,
    page: page,
    serverId: created.serverId,
  );
  if (!placed) {
    messenger.showSnackBar(SnackBar(content: Text(l.highlightNotPlaced)));
  }
  return true;
}

/// Lets the owner change the note, color and spoiler flag of [annotation].
Future<void> editAnnotation(
  BuildContext context,
  WidgetRef ref,
  AnnotationModel annotation,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final draft = await showAnnotationEditor(
    context,
    ref,
    selectedText: annotation.selectedText,
    annotation: annotation,
  );
  if (draft == null) return;

  await container
      .read(annotationRepositoryProvider)
      .updateAnnotation(
        annotation,
        comment: draft.comment,
        selectedSlotIndex: draft.selectedSlotIndex,
        containsSpoiler: draft.containsSpoiler,
      );
}

/// Asks for confirmation and deletes [annotation].
Future<void> deleteAnnotation(
  BuildContext context,
  WidgetRef ref,
  AnnotationModel annotation,
) async {
  final l = AppLocalizations.of(context);
  final colorScheme = Theme.of(context).colorScheme;
  final container = ProviderScope.containerOf(context, listen: false);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.deleteAnnotationTitle),
      content: Text(l.deleteAnnotationContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.delete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final deleted = await container
      .read(annotationRepositoryProvider)
      .deleteAnnotation(annotation);
  // The server rewrote the highlighted paragraph as plain text: fetch it
  // again to get its markup back. Offline the highlight just loses its color.
  if (deleted) {
    await refreshAnnotatedPage(
      container,
      chapterId: annotation.chapterId,
      page: annotation.page,
    );
  }
}

/// Shows [page] of [chapterId] again as the server now renders it, after a
/// highlight was created or deleted, refreshing its downloaded copy too.
/// Returns whether the page holds the highlight with [serverId], if given.
Future<bool> refreshAnnotatedPage(
  ProviderContainer container, {
  required int chapterId,
  required int page,
  int? serverId,
}) async {
  try {
    await container
        .read(downloadRepositoryProvider)
        .refreshEpubPage(chapterId: chapterId, page: page);
  } catch (e) {
    log.info('could not refresh downloaded page', attributes: {'error': e});
  }

  final provider = epubPageProvider(chapterId: chapterId, page: page);
  container.invalidate(provider);
  if (serverId == null) return true;

  try {
    final content = await container.read(provider.future);
    return content.root.querySelector(
          '#${HtmlConstants.highlightIdPrefix}$serverId',
        ) !=
        null;
  } catch (_) {
    return false;
  }
}
