import 'dart:typed_data';

import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/epub_font_dto_mappings.dart';
import 'package:kover/utils/logging.dart';

class FontSyncOperations({
  required final Openapi client,
}) {
  /// Fetch all server-side epub fonts metadata
  Future<List<ServerFontsCompanion>> getServerFonts() async {
    final res = await client.apiFontAllGet();

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load server fonts: ${res.error}');
    }

    return res.body!.map((dto) => dto.toServerFontsCompanion()).toList();
  }

  /// Fetches the raw file for server font [fontId].
  Future<({Uint8List bytes, String mimeType})?> getServerFontBytes(
    int fontId,
  ) async {
    try {
      final res = await client.apiFontGet(fontId: fontId);

      if (res.isSuccessful && res.bodyBytes.isNotEmpty) {
        final mimeType = res.headers['content-type'] ?? 'font/ttf';
        return (bytes: res.bodyBytes, mimeType: mimeType);
      }
    } catch (e) {
      log.warning(
        'failed to fetch server font',
        attributes: {'fontId': fontId, 'error_type': e.runtimeType},
      );
    }

    return null;
  }
}
