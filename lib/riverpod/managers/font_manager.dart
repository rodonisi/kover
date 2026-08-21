import 'package:flutter/services.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/riverpod/repository/font_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_manager.g.dart';

/// Loads fonts into the Flutter engine, pulling their bytes from the font
/// cache or the server on demand, and ensuring each unique font family is
/// only registered once per session.
@Riverpod(keepAlive: true)
class FontManager extends _$FontManager {
  @override
  Set<String> build() {
    return {};
  }

  /// Registers every font face in [fonts] with the engine.
  Future<void> ensureLoaded(List<FontFace> fonts) async {
    final repository = ref.read(fontRepositoryProvider);

    final grouped = <String, List<Uint8List>>{};
    for (final face in fonts) {
      final data = await repository.getFontData(face);
      if (data == null || data.isEmpty) continue;

      grouped.putIfAbsent(face.family, () => []).add(data);
    }

    if (!ref.mounted) return;

    for (final entry in grouped.entries) {
      await _register(entry.key, entry.value);
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
