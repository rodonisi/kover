import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kover/models/bookmark_model.dart';
import 'package:kover/models/image_model.dart';
import 'package:kover/riverpod/providers/bookmark.dart';
import 'package:kover/riverpod/providers/connectivity.dart';
import 'package:kover/riverpod/providers/reader.dart';
import 'package:kover/riverpod/repository/book_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<BookRepository>()])
import 'bookmark_test.mocks.dart';

void main() {
  provideDummy<ImageModel>(ImageModel(data: Uint8List(0)));

  BookmarkModel bookmark({required int id, required int chapterId}) {
    return BookmarkModel(
      id: id,
      seriesId: 1,
      volumeId: 1,
      chapterId: chapterId,
      page: id,
      created: DateTime(2026),
    );
  }

  test('readableBookmarks keeps only chapters that can be read', () async {
    final readable = bookmark(id: 1, chapterId: 1);
    final notReadable = bookmark(id: 2, chapterId: 2);

    final container = ProviderContainer.test(
      overrides: [
        bookmarksProvider(
          seriesId: 1,
        ).overrideWith((ref) => Stream.value([readable, notReadable])),
        canReadChapterProvider(1).overrideWith((ref) => Stream.value(true)),
        canReadChapterProvider(2).overrideWith((ref) => Stream.value(false)),
      ],
    );

    final subscription = container.listen(
      readableBookmarksProvider(seriesId: 1),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(bookmarksProvider(seriesId: 1).future);
    await container.read(canReadChapterProvider(1).future);
    await container.read(canReadChapterProvider(2).future);
    await container.pump();

    expect(subscription.read(), [readable]);
  });

  test('bookmarkImage refetches when connectivity is regained', () async {
    final target = bookmark(id: 1, chapterId: 10);
    final repo = MockBookRepository();
    var attempts = 0;
    when(repo.getImagePage(chapterId: 10, page: 1)).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('offline');
      return ImageModel(data: Uint8List.fromList([1, 2, 3]));
    });

    final connectivity = StreamController<bool>();
    addTearDown(connectivity.close);

    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        bookRepositoryProvider.overrideWithValue(repo),
        hasConnectionProvider.overrideWith((ref) => connectivity.stream),
      ],
    );

    final subscription = container.listen(
      bookmarkImageProvider(target),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(bookmarkImageProvider(target).future),
      throwsA(isA<Exception>()),
    );
    expect(attempts, 1);

    connectivity.add(true);
    await container.pump();

    final image = await container.read(bookmarkImageProvider(target).future);
    expect(image.data, [1, 2, 3]);
    expect(attempts, 2);
  });
}
