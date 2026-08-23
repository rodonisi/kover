import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';
import 'package:kover/database/converters/page_content_converter.dart';
import 'package:kover/models/enums/format.dart';
import 'package:kover/models/page_content.dart';
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

@visibleForTesting
final pageBlobConverter = TypeConverter.jsonb<Map<String, dynamic>>(
  fromJson: (json) => json as Map<String, dynamic>,
);

/// Moves the font bytes embedded in pre-migration epub page blobs into the
/// fonts table and rewrites the blobs to only carry [FontFace] models.
///
/// Legacy blobs embed their bytes as a `{family: [bytes]}` map whose order
/// matches the order of the `@font-face` sources declared in the stored
/// HTML, so faces and bytes are paired by index within each family. Blobs
/// that cannot be decoded are skipped; every decodable legacy blob is
/// rewritten to the new format, even when no face can be migrated, because
/// leaving the legacy map behind would break JSON decoding of the page at
/// read time.
Future<void> _migrateLegacyPageFonts(AppDatabase db) async {
  final relevantChaptersQuery =
      db.selectOnly(db.chapters).join([
          innerJoin(
            db.downloadedPages,
            db.chapters.id.equalsExp(db.downloadedPages.chapterId),
          ),
        ])
        ..addColumns([db.chapters.id])
        ..where(db.chapters.format.equals(Format.epub.name))
        ..groupBy([db.chapters.id]);

  final relevantChapters = await relevantChaptersQuery
      .map((result) => result.read(db.chapters.id))
      .get();

  for (final id in relevantChapters) {
    if (id == null) continue;

    final pagesQuery = db.select(db.downloadedPages)
      ..where((tbl) => tbl.chapterId.equals(id));
    final pages = await pagesQuery.get();

    for (final page in pages) {
      try {
        final blob = pageBlobConverter.fromSql(page.data);

        final legacyFonts = blob['fonts'];
        if (legacyFonts is List) continue;

        final root = parseFragment(blob['root'] as String? ?? '');
        final faces = EpubFontParser.parseStyles(
          root.querySelectorAll('style'),
        );

        final consumedPerFamily = <String, int>{};
        for (final face in faces) {
          final familyBytes = legacyFonts is Map
              ? legacyFonts[face.family]
              : null;
          if (familyBytes is! List || familyBytes.isEmpty) continue;

          final index = consumedPerFamily.update(
            face.family,
            (count) => count + 1,
            ifAbsent: () => 0,
          );
          if (index >= familyBytes.length) continue;

          final data = Uint8List.fromList(
            base64Decode(familyBytes[index] as String),
          );
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

        blob['fonts'] = [for (final face in faces) face.toJson()];
        final updatedContent = PageContent.fromJson(blob);

        await (db.update(db.downloadedPages)..where(
              (tbl) => tbl.chapterId.equals(id) & tbl.page.equals(page.page),
            ))
            .write(
              DownloadedPagesCompanion(
                data: Value(pageContentConverter.toSql(updatedContent)),
              ),
            );

        log.info(
          'migrated legacy epub page fonts',
          attributes: {'chapter_id': id, 'page': page},
        );
      } catch (e, stacktrace) {
        log.error(
          'failed to migrate fonts of downloaded epub page',
          error: e,
          stacktrace: stacktrace,
          attributes: {'chapter_id': id, 'page': page},
        );
      }
    }
  }
}
