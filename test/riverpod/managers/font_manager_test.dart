import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/riverpod/managers/font_manager.dart';
import 'package:kover/riverpod/repository/font_repository.dart';
import 'package:kover/riverpod/repository/server_fonts_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'font_manager_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FontRepository>(),
  MockSpec<ServerFontsRepository>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFontRepository fonts;
  late MockServerFontsRepository serverFonts;
  late ProviderContainer container;

  const regular = FontFace(family: 'Book', url: 'fonts://book/regular.ttf');
  const bold = FontFace(
    family: 'Book',
    weight: 700,
    url: 'fonts://book/bold.ttf',
  );
  final bytes = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    fonts = MockFontRepository();
    serverFonts = MockServerFontsRepository();
    container = ProviderContainer.test(
      overrides: [
        fontRepositoryProvider.overrideWithValue(fonts),
        serverFontsRepositoryProvider.overrideWithValue(serverFonts),
      ],
    );
  });

  FontManager manager() => container.read(fontManagerProvider.notifier);
  Set<String> registered() => container.read(fontManagerProvider);

  group('ensureLoaded', () {
    test('fetches each face once for pages loading together', () async {
      when(fonts.getFontData(any)).thenAnswer((_) async => bytes);

      await Future.wait([
        manager().ensureLoaded([regular, bold]),
        manager().ensureLoaded([regular, bold]),
      ]);

      verify(fonts.getFontData(regular)).called(1);
      verify(fonts.getFontData(bold)).called(1);
      expect(registered(), {regular.url, bold.url});
    });

    test('does not fetch registered faces again', () async {
      when(fonts.getFontData(any)).thenAnswer((_) async => bytes);

      await manager().ensureLoaded([regular]);
      await manager().ensureLoaded([regular, bold]);

      verify(fonts.getFontData(regular)).called(1);
      verify(fonts.getFontData(bold)).called(1);
    });

    test('fetches a face without bytes again next time', () async {
      when(fonts.getFontData(any)).thenAnswer((_) async => null);

      await manager().ensureLoaded([regular]);
      await manager().ensureLoaded([regular]);

      verify(fonts.getFontData(regular)).called(2);
      expect(registered(), isEmpty);
    });
  });

  group('ensureServerFontLoaded', () {
    test('reads a family once', () async {
      when(
        serverFonts.getBytesByFamily('Literata'),
      ).thenAnswer((_) async => [bytes]);

      await manager().ensureServerFontLoaded('Literata');
      await manager().ensureServerFontLoaded('Literata');

      verify(serverFonts.getBytesByFamily('Literata')).called(1);
      expect(registered(), {'server:Literata'});
    });

    test('reads a family without bytes again next time', () async {
      when(
        serverFonts.getBytesByFamily('Literata'),
      ).thenAnswer((_) async => []);

      await manager().ensureServerFontLoaded('Literata');
      await manager().ensureServerFontLoaded('Literata');

      verify(serverFonts.getBytesByFamily('Literata')).called(2);
      expect(registered(), isEmpty);
    });
  });
}
