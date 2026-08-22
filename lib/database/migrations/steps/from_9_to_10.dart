import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:html/parser.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/utils/epub_font_parser.dart';
import 'package:kover/utils/logging.dart';

Future<void> migrateFrom9To10(
  AppDatabase db,
  Migrator m,
  Schema10 schema,
) async {
  await db.transaction(() async {
    await m.createTable(schema.fonts);
    await _migrateLegacyPageFonts(db);
  });
}

/// Moves the font bytes embedded in pre-migration epub page blobs into the
/// fonts table and rewrites the blobs to only carry [FontFace] models.
///
/// Legacy blobs embed their bytes as a `{family: font}` map holding at most
/// one base64-encoded font per family. Every legacy blob is rewritten to the
/// new format, even when no face can be migrated.
Future<void> _migrateLegacyPageFonts(AppDatabase db) async {
  final pages = db.downloadedPages;
  final chapters = db.chapters;

  final chapterId = chapters.id;
  final relevantChaptersQuery =
      db.selectOnly(chapters).join([
          innerJoin(pages, chapterId.equalsExp(pages.chapterId)),
        ])
        ..addColumns([chapterId])
        ..where(chapters.format.equals(Format.epub.name))
        ..groupBy([chapterId]);

  final relevantChapters = await relevantChaptersQuery
      .map((result) => result.read(chapters.id))
      .get();

  for (final chapter in relevantChapters) {
    if (chapter == null) continue;

    final pagesList = await (db.select(
      pages,
    )..where((tbl) => tbl.chapterId.equals(chapter))).get();

    for (final page in pagesList) {
      try {
        final blob = jsonDecode(utf8.decode(page.data)) as Map<String, dynamic>;
        final legacyFonts = blob['fonts'];
        if (legacyFonts is List) continue;

        final root = parseFragment(blob['root'] as String? ?? '');
        final faces = EpubFontParser.parseStyles(
          root.querySelectorAll('style'),
        );

        await _storeFamilyBlobs(db, faces, legacyFonts);

        blob['fonts'] = [for (final face in faces) face.toJson()];
        await (db.update(pages)..where(
              (tbl) =>
                  tbl.chapterId.equals(chapter) & tbl.page.equals(page.page),
            ))
            .write(
              DownloadedPagesCompanion(
                data: Value(utf8.encode(jsonEncode(blob))),
              ),
            );

        log.info(
          'migrated legacy epub page fonts',
          attributes: {'chapter_id': chapter, 'page': page.page},
        );
      } catch (e, stacktrace) {
        log.error(
          'failed to migrate fonts of downloaded epub page',
          error: e,
          stacktrace: stacktrace,
          attributes: {'chapter_id': chapter, 'page': page.page},
        );
      }
    }
  }
}

/// Stores the embedded font bytes of a legacy `{family: font}` map in the
/// fonts table.
///
/// The old schema carried at most one font per family: the first face of a
/// family claims the stored bytes under its url, later faces of the same
/// family fall back to fetching from the server at runtime.
Future<void> _storeFamilyBlobs(
  AppDatabase db,
  List<FontFace> faces,
  Object? legacyFonts,
) async {
  if (legacyFonts is! Map || legacyFonts.isEmpty) return;

  final claimedFamilies = <String>{};
  for (final face in faces) {
    if (!claimedFamilies.add(face.family)) continue;

    final data = _decodeFontBlob(legacyFonts[face.family]);
    if (data == null) continue;

    await db
        .into(db.fonts)
        .insert(
          FontsCompanion.insert(
            family: face.family,
            weight: Value(face.weight),
            url: face.url,
            data: data,
          ),
          onConflict: DoUpdate(
            (_) => FontsCompanion.insert(
              family: face.family,
              weight: Value(face.weight),
              url: face.url,
              data: data,
            ),
            target: [db.fonts.url],
          ),
        );
  }
}

/// Decode the value of a single legacy map entry into raw font bytes.
Uint8List? _decodeFontBlob(Object? value) {
  // The old serializer wrote a list of base64 strings per family.
  if (value is List) {
    if (value.isEmpty) return null;

    final entry = value.first;
    if (entry is String) return _decodeBase64(entry);

    return null;
  }

  return _decodeBase64(value as String? ?? '');
}

Uint8List? _decodeBase64(String encoded) {
  if (encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}
