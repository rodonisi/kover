import 'package:drift/drift.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/database/app_database.steps.dart';
import 'package:kover/models/enums/publication_status.dart';

Future<void> migrateFrom8To9(AppDatabase db, Migrator m, Schema9 schema) async {
  await db.transaction(() async {
    await m.alterTable(
      TableMigration(
        schema.seriesMetadata,
        newColumns: [
          schema.seriesMetadata.maxCount,
          schema.seriesMetadata.totalCount,
          schema.seriesMetadata.publicationStatus,
          schema.seriesMetadata.webLinks,
        ],
        columnTransformer: {
          schema.seriesMetadata.maxCount: const Constant(0),
          schema.seriesMetadata.totalCount: const Constant(0),
          schema.seriesMetadata.publicationStatus: Constant(
            PublicationStatus.unknown.name,
          ),
          schema.chapters.ageRating: coalesce([
            schema.chapters.ageRating,
            const Constant(0),
          ]),
          schema.seriesMetadata.lastUpdated: const Constant(0),
        },
      ),
    );
    await m.alterTable(
      TableMigration(
        schema.people,
        newColumns: [
          schema.people.primaryColor,
          schema.people.secondaryColor,
          schema.people.description,
          schema.people.aliases,
        ],
      ),
    );
    await m.createTable(schema.chapterPeopleRoles);
    await m.createTable(schema.chapterGenres);
    await m.createTable(schema.chapterTags);
    await m.alterTable(
      TableMigration(
        schema.chapters,
        newColumns: [
          schema.chapters.publicationStatus,
          schema.chapters.webLinks,
        ],
        columnTransformer: {
          schema.chapters.publicationStatus: Constant(
            PublicationStatus.unknown.name,
          ),
          schema.chapters.ageRating: coalesce([
            schema.chapters.ageRating,
            const Constant(0),
          ]),
        },
      ),
    );
    await m.drop(schema.seriesPeopleRoles);
    await m.createTable(schema.seriesPeopleRoles);
    await m.alterTable(
      TableMigration(
        schema.series,
        columnTransformer: {
          schema.series.lastSynced: const Constant(null),
        },
      ),
    );
  });
}
