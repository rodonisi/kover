import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        // Recommended for widget tests to avoid test errors.
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('FontDao', () {
    group('getByUrl', () {
      test(
        'when a font was cached, then returns it',
        () {
          fakeAsync((async) {
            Font? font;
            const url = 'fonts://test/regular.ttf';

            database.fontDao
                .upsertFont(
                  FontsCompanion.insert(
                    family: 'Test',
                    weight: const Value(400),
                    url: url,
                    data: Uint8List.fromList([1, 2, 3]),
                    mimeType: const Value('font/ttf'),
                  ),
                )
                .then((_) {});

            database.fontDao.getByUrl(url: url).then((v) => font = v);

            async.flushMicrotasks();

            expect(font, isNotNull);
            expect(font!.family, 'Test');
            expect(font!.name, isNull);
            expect(font!.weight, 400);
            expect(font!.mimeType, 'font/ttf');
            expect(font!.data, Uint8List.fromList([1, 2, 3]));
          });
        },
      );

      test(
        'when the url was never cached, then returns null',
        () {
          fakeAsync((async) {
            Font? font;

            database.fontDao.getByUrl(url: 'missing').then((v) => font = v);

            async.flushMicrotasks();

            expect(font, isNull);
          });
        },
      );
    });

    group('upsertFont', () {
      test(
        'when the same url is upserted twice, then replaces the row',
        () {
          fakeAsync((async) {
            List<Font> rows = [];
            Font? font;
            const url = 'fonts://test/regular.ttf';

            database.fontDao
                .upsertFont(
                  FontsCompanion.insert(
                    family: 'Old',
                    url: url,
                    data: Uint8List.fromList([1]),
                  ),
                )
                .then((_) {});
            database.fontDao
                .upsertFont(
                  FontsCompanion.insert(
                    family: 'New',
                    weight: const Value(700),
                    url: url,
                    data: Uint8List.fromList([2]),
                  ),
                )
                .then((_) {});

            database.select(database.fonts).get().then((v) => rows = v);
            database.fontDao.getByUrl(url: url).then((v) => font = v);

            async.flushMicrotasks();

            expect(rows, hasLength(1));
            expect(font!.family, 'New');
            expect(font!.weight, 700);
            expect(font!.data, Uint8List.fromList([2]));
          });
        },
      );
    });
  });
}
