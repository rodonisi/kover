import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
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
        () {
          fakeAsync((async) {
            Uint8List? data;

            database.fontDao
                .upsertFont(
                  FontsCompanion.insert(
                    family: face.family,
                    url: face.url,
                    data: Uint8List.fromList([9, 9]),
                  ),
                )
                .then((_) {});

            repository.getFontData(face).then((v) => data = v);

            async.flushMicrotasks();

            expect(data, Uint8List.fromList([9, 9]));
            verifyNever(client.getFontBytes(any));
          });
        },
      );

      test(
        'when the font is not cached, then fetches and returns its bytes',
        () {
          fakeAsync((async) {
            Uint8List? data;
            List<Font> rows = [];

            when(client.getFontBytes(any)).thenAnswer((_) async => fontBytes);

            repository.getFontData(face).then((v) => data = v);
            database.select(database.fonts).get().then((v) => rows = v);

            async.flushMicrotasks();

            expect(data, fontBytes.bytes);
            verify(client.getFontBytes(face.url)).called(1);
            expect(rows, isEmpty);
          });
        },
      );

      test(
        'when the fetch fails, then returns null',
        () {
          fakeAsync((async) {
            Uint8List? data;

            when(client.getFontBytes(any)).thenAnswer((_) async => null);

            repository.getFontData(face).then((v) => data = v);

            async.flushMicrotasks();

            expect(data, isNull);
          });
        },
      );
    });

    group('saveFonts', () {
      test(
        'when a font is new, then fetches and persists it',
        () {
          fakeAsync((async) {
            List<Font> rows = [];

            when(client.getFontBytes(any)).thenAnswer((_) async => fontBytes);

            repository.saveFonts([face]).then((_) {
              database.select(database.fonts).get().then((v) => rows = v);
            });

            async.flushMicrotasks();

            expect(rows, hasLength(1));
            expect(rows.single.family, face.family);
            expect(rows.single.url, face.url);
            expect(rows.single.data, fontBytes.bytes);
            expect(rows.single.mimeType, fontBytes.mimeType);
          });
        },
      );

      test(
        'when a font is already cached, then does not fetch it again',
        () {
          fakeAsync((async) {
            List<Font> rows = [];

            when(client.getFontBytes(any)).thenAnswer((_) async => fontBytes);

            repository.saveFonts([face]).then((_) {});

            async.flushMicrotasks();
            clearInteractions(client);

            repository.saveFonts([face]).then((_) {
              database.select(database.fonts).get().then((v) => rows = v);
            });

            async.flushMicrotasks();

            verifyNever(client.getFontBytes(any));
            expect(rows, hasLength(1));
          });
        },
      );

      test(
        'when a fetch fails, then still saves the remaining fonts',
        () {
          fakeAsync((async) {
            List<Font> rows = [];
            const otherFace = FontFace(
              family: 'OtherFont',
              url: 'fonts://o/regular.ttf',
            );

            when(client.getFontBytes(face.url)).thenAnswer((_) async => null);
            when(client.getFontBytes(otherFace.url))
                .thenAnswer((_) async => fontBytes);

            repository.saveFonts([face, otherFace]).then((_) {
              database.select(database.fonts).get().then((v) => rows = v);
            });

            async.flushMicrotasks();

            expect(rows.map((r) => r.family), ['OtherFont']);
          });
        },
      );

      test(
        'when two fonts share an url, then only one row and one fetch happen',
        () {
          fakeAsync((async) {
            List<Font> rows = [];

            when(client.getFontBytes(any)).thenAnswer((_) async => fontBytes);

            repository
                .saveFonts([
                  face,
                  FontFace(
                    family: 'SameFile',
                    weight: 700,
                    url: face.url,
                  ),
                ])
                .then((_) {
                  database.select(database.fonts).get().then((v) => rows = v);
                });

            async.flushMicrotasks();

            verify(client.getFontBytes(face.url)).called(1);
            expect(rows, hasLength(1));
          });
        },
      );
    });
  });
}
