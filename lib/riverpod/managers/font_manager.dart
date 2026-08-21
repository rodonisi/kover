import 'package:flutter/services.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/riverpod/repository/font_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_manager.g.dart';

/// Loads fonts into the Flutter engine, pulling their bytes from the font
/// cache or the server on demand, and ensuring each unique font is only
/// registered once per session.
@riverpod
class FontManager extends _$FontManager {
  @override
  Set<String> build() {
    return {};
  }

  /// Registers every font face in [fonts] with the engine. Duplicate faces
  /// (same family + bytes) are skipped. Unavailable fonts are skipped.
  Future<void> ensureLoaded(List<FontFace> fonts) async {
    final repository = ref.read(fontRepositoryProvider);

    for (final face in fonts) {
      final data = await repository.getFontData(face);
      if (data == null) continue;

      await _register(face.family, data);
    }
  }

  Future<void> _register(String family, Uint8List bytes) async {
    if (bytes.isEmpty) return;

    final key = '$family:${Object.hashAll(bytes)}';
    if (state.contains(key)) return;

    try {
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    } catch (e) {
      log.warning(
        'failed to register font, ignoring: $e',
        attributes: {'family': family, 'size': bytes.length},
      );
      return;
    }
    state = {...state, key};

    log.debug(
      'registered font',
      attributes: {'family': family, 'size': bytes.length},
    );
  }
}
