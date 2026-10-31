import 'dart:async';

import 'package:flutter/services.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/riverpod/repository/font_repository.dart';
import 'package:kover/riverpod/repository/server_fonts_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_manager.g.dart';

/// Loads fonts into the Flutter engine, pulling their bytes from the db or the
/// server on demand, and ensuring each font is only registered once per
/// session.
///
/// The state holds the keys of the registered fonts: `server:<family>` for
/// server fonts and the url of each epub font face.
@Riverpod(keepAlive: true)
class FontManager extends _$FontManager {
  /// Fonts being loaded, by key, so that the pages of a book that load at the
  /// same time share one fetch.
  final _loading = <String, Future<void>>{};

  @override
  Set<String> build() {
    return {};
  }

  /// Registers the server font family [family] with the engine if it has not
  /// already been registered.
  Future<void> ensureServerFontLoaded(String family) {
    return _ensure('server:$family', family, () {
      return ref.read(serverFontsRepositoryProvider).getBytesByFamily(family);
    });
  }

  /// Registers every font face in [fonts] with the engine, fetching the
  /// missing ones in parallel.
  Future<void> ensureLoaded(List<FontFace> fonts) async {
    final repository = ref.read(fontRepositoryProvider);

    await Future.wait([
      for (final face in fonts)
        _ensure(face.url, face.family, () async {
          final data = await repository.getFontData(face);
          return [?data];
        }),
    ]);
  }

  /// Registers the font bytes returned by [load] as [family] under [key],
  /// unless [key] is registered already. Fonts without bytes are not marked
  /// as registered, so they are tried again next time.
  Future<void> _ensure(
    String key,
    String family,
    Future<List<Uint8List>> Function() load,
  ) {
    if (state.contains(key)) return Future.value();

    return _loading[key] ??= _load(key, family, load);
  }

  Future<void> _load(
    String key,
    String family,
    Future<List<Uint8List>> Function() load,
  ) async {
    try {
      final datas = (await load()).where((data) => data.isNotEmpty);
      if (datas.isEmpty || !ref.mounted) return;

      await _register(key, family, datas.toList());
    } finally {
      // Removes this very future, which is completing.
      unawaited(_loading.remove(key));
    }
  }

  Future<void> _register(
    String key,
    String family,
    List<Uint8List> datas,
  ) async {
    try {
      final loader = FontLoader(family);
      for (final data in datas) {
        loader.addFont(Future.value(ByteData.sublistView(data)));
      }
      await loader.load();
    } catch (e) {
      log.warning(
        'failed to register font family, ignoring: $e',
        attributes: {'family': family, 'count': datas.length},
      );
      return;
    }
    state = {...state, key};

    log.debug(
      'registered font family',
      attributes: {'family': family, 'count': datas.length},
    );
  }
}
