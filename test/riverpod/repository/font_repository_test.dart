import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/riverpod/repository/font_repository.dart';
import 'package:kover/sync/book_sync_operations.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'font_repository_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BookSyncOperations>()])
void main() {
  late AppDatabase database;
  late MockBookSyncOperations client;
  late FontRepository repository;

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        // Recommended for widget tests to avoid test errors.
        closeStreamsSynchronously: true,
      ),
    );
    client = MockBookSyncOperations();
    repository = FontRepository(database, client);
  });

  tearDown(() async {
    await database.close();
  });

  const face = FontFace(family: 'TestFont', url: 'fonts://t/regular.ttf');

  final fontBytes = (
    bytes: Uint8List.fromList([1, 2, 3]),
    mimeType: 'font/ttf',
  );

  group('FontRepository', () {
    group('getFontData', () {
      test(
        'when the font is cached, then returns the cached bytes',
        () async {
          await database.fontDao.upsertFont(
            FontsCompanion.insert(
              family: face.family,
              url: face.url,
              data: Uint8List.fromList([9, 9]),
            ),
          );

          final data = await repository.getFontData(face);

          expect(data, Uint8List.fromList([9, 9]));
          verifyNever(client.getFontBytes(any));
        },
      );

      test(
        'when the font is not cached, then fetches and returns its bytes',
        () async {
          when(client.getFontBytes(any)).thenAnswer((_) async => fontBytes);

          final data = await repository.getFontData(face);

          expect(data, fontBytes.bytes);
          verify(client.getFontBytes(face.url)).called(1);
          expect(await database.select(database.fonts).get(), isEmpty);
        },
      );

      test(
        'when the fetch fails, then returns null',
        () async {
          when(client.getFontBytes(any)).thenAnswer((_) async => null);

          final data = await repository.getFontData(face);

          expect(data, isNull);
        },
      );
    });

    group('cacheFonts', () {
      test(
        'when a face is new, then fetches and persists it',
        () async {
          when(client.getFontBytes(any)).thenAnswer((_) async => fontBytes);

          await repository.cacheFonts([face]);

          final rows = await database.select(database.fonts).get();
          expect(rows, hasLength(1));
          expect(rows.single.family, face.family);
          expect(rows.single.url, face.url);
          expect(rows.single.data, fontBytes.bytes);
          expect(rows.single.mimeType, fontBytes.mimeType);
        },
      );

      test(
        'when a face is already cached, then does not fetch it again',
        () async {
          when(client.getFontBytes(any)).thenAnswer((_) async => fontBytes);
          await repository.cacheFonts([face]);
          clearInteractions(client);

          await repository.cacheFonts([face]);

          verifyNever(client.getFontBytes(any));
          final rows = await database.select(database.fonts).get();
          expect(rows, hasLength(1));
        },
      );

      test(
        'when a fetch fails, then still caches the remaining faces',
        () async {
          const otherFace = FontFace(
            family: 'OtherFont',
            url: 'fonts://o/regular.ttf',
          );
          when(client.getFontBytes(face.url)).thenAnswer((_) async => null);
          when(client.getFontBytes(otherFace.url))
              .thenAnswer((_) async => fontBytes);

          await repository.cacheFonts([face, otherFace]);

          final rows = await database.select(database.fonts).get();
          expect(rows.map((r) => r.family), ['OtherFont']);
        },
      );

      test(
        'when two faces share an url, then only one row and one fetch happen',
        () async {
          when(client.getFontBytes(any)).thenAnswer((_) async => fontBytes);

          await repository.cacheFonts([
            face,
            FontFace(
              family: 'SameFile',
              weight: 700,
              url: face.url,
            ),
          ]);

          verify(client.getFontBytes(face.url)).called(1);
          final rows = await database.select(database.fonts).get();
          expect(rows, hasLength(1));
        },
      );
    });
  });
}
