import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:html/parser.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';
import 'package:kover/models/enums/format.dart';
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
/// fonts table and rewrites the blobs to only carry `FontFace` descriptors.
///
/// Legacy blobs embed their bytes as a `{family: [bytes]}` map whose order
/// matches the order of the `@font-face` sources declared in the stored
/// HTML, so faces and bytes are paired by index within each family.
Future<void> _migrateLegacyPageFonts(AppDatabase db) async {
  final rows = await (db.select(db.downloadedPages).join([
    innerJoin(
      db.chapters,
      db.chapters.id.equalsExp(db.downloadedPages.chapterId),
    ),
  ])..where(db.chapters.format.equals(Format.epub.name))).get();

  for (final row in rows) {
    final chapterId = row.read(db.chapters.id);
    final page = row.read(db.downloadedPages.page);

    if (chapterId == null || page == null) continue;

    try {
      final blob = jsonDecode(
        utf8.decode(row.read(db.downloadedPages.data) as Uint8List),
      );
      if (blob is! Map<String, dynamic>) continue;

      final legacyFonts = blob['fonts'];
      if (legacyFonts is! Map<String, dynamic> || legacyFonts.isEmpty) {
        continue;
      }

      final root = parseFragment(blob['root'] as String? ?? '');
      final faces = EpubFontParser.parseStyles(
        root.querySelectorAll('style'),
      );

      var migrated = false;
      final consumedPerFamily = <String, int>{};
      for (final face in faces) {
        final familyBytes = legacyFonts[face.family];
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
        migrated = true;
      }

      if (!migrated) continue;

      blob['fonts'] = [for (final face in faces) face.toJson()];
      await (db.update(db.downloadedPages)..where(
            (tbl) => tbl.chapterId.equals(chapterId) & tbl.page.equals(page),
          ))
          .write(
            DownloadedPagesCompanion(
              data: Value(utf8.encode(jsonEncode(blob))),
            ),
          );

      log.info(
        'migrated legacy epub page fonts',
        attributes: {'chapter_id': chapterId, 'page': page},
      );
    } catch (e, stacktrace) {
      log.error(
        'failed to migrate fonts of downloaded epub page',
        error: e,
        stacktrace: stacktrace,
        attributes: {'chapter_id': chapterId, 'page': page},
      );
    }
  }
}
