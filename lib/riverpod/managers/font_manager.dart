import 'package:flutter/services.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/riverpod/repository/font_repository.dart';
import 'package:kover/riverpod/repository/server_fonts_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_manager.g.dart';

/// Loads fonts into the Flutter engine, pulling their bytes from the db or the
/// server on demand, and ensuring each unique font family is only registered
/// once per session.
@Riverpod(keepAlive: true)
class FontManager extends _$FontManager {
  @override
  Set<String> build() => {};

  /// Registers the server font family [family] with the engine if it has not
  /// already been registered.
  Future<void> ensureServerFontLoaded(String family) async {
    final data = await _loadFamilyBytes(family);
    if (data == null || data.isEmpty) return;

    await _register(family, data);
  }

  /// Registers every font face in [fonts] with the engine.
  Future<void> ensureLoaded(List<FontFace> fonts) async {
    final grouped = <String, List<Uint8List>>{};

    for (final face in fonts) {
      final data = await _loadFaceBytes(face);
      if (data == null || data.isEmpty) continue;

      grouped.putIfAbsent(face.family, () => []).add(data);
    }

    await Future.wait([
      for (final entry in grouped.entries) _register(entry.key, entry.value),
    ]);
  }

  Future<List<Uint8List>?> _loadFamilyBytes(String family) async {
    try {
      return await ref.read(fontFamilyProvider(family: family).future);
    } catch (e) {
      log.debug(
        'failed to load server font family, ignoring',
        attributes: {'family': family, 'error': e},
      );
      ref.invalidate(fontFamilyProvider(family: family));
      return null;
    }
  }

  Future<Uint8List?> _loadFaceBytes(FontFace face) async {
    try {
      return await ref.read(fontFaceProvider(face: face).future);
    } catch (e) {
      log.debug(
        'failed to load font face, ignoring',
        attributes: {'url': face.url, 'error': e},
      );
      ref.invalidate(fontFaceProvider(face: face));
      return null;
    }
  }

  Future<void> _register(String family, List<Uint8List> datas) async {
    final key = '$family:${Object.hashAll(datas.map(Object.hashAll))}';
    if (state.contains(key)) return;

    try {
      final loader = FontLoader(family);
      for (final data in datas) {
        loader.addFont(Future.value(ByteData.sublistView(data)));
      }
      await loader.load();
    } catch (e) {
      log.debug(
        'failed to register font family, ignoring',
        attributes: {'family': family, 'count': datas.length, 'error': e},
      );
      return;
    }

    if (!ref.mounted) return;

    state = {...state, key};

    log.debug(
      'registered font family',
      attributes: {'family': family, 'count': datas.length},
    );
  }
}

@Riverpod(keepAlive: true)
Future<Uint8List?> fontFace(Ref ref, {required FontFace face}) async {
  final repository = ref.watch(fontRepositoryProvider);
  return repository.getFontData(face);
}

@Riverpod(keepAlive: true)
Future<List<Uint8List>> fontFamily(Ref ref, {required String family}) async {
  final repository = ref.watch(serverFontsRepositoryProvider);
  return repository.getBytesByFamily(family);
}
