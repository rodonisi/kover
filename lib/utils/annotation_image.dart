import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

abstract final class AnnotationImage {
  // shortcut: picked images embed as base64, add upload/compression if payloads grow.
  static Future<String> toPortableSource(String source) async {
    if (_isPortable(source)) return source;

    final file = XFile(source);
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? _mimeType(source, bytes);
    if (mimeType == null) {
      throw UnsupportedError('Unsupported image format');
    }

    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  static void insert({
    required QuillController controller,
    required String source,
  }) {
    final index = controller.selection.baseOffset;
    final length = controller.selection.extentOffset - index;
    controller
      ..skipRequestKeyboard = true
      ..replaceText(index, length, BlockEmbed.image(source), null)
      ..moveCursorToPosition(index + 1);
  }

  static bool _isPortable(String source) {
    if (source.startsWith('data:image/')) return true;

    final scheme = Uri.tryParse(source)?.scheme;
    return scheme == 'http' || scheme == 'https';
  }

  static String? _mimeType(String source, List<int> bytes) {
    return _mimeTypeFromBytes(bytes) ??
        _mimeTypes[p.extension(source).toLowerCase()];
  }

  static String? _mimeTypeFromBytes(List<int> bytes) {
    if (_startsWith(bytes, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return 'image/png';
    }
    if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (_startsWith(bytes, ascii.encode('GIF87a')) ||
        _startsWith(bytes, ascii.encode('GIF89a'))) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp') {
      final brand = ascii.decode(bytes.sublist(8, 12), allowInvalid: true);
      if (const {
        'heic',
        'heix',
        'hevc',
        'hevx',
        'mif1',
        'msf1',
      }.contains(brand)) {
        return 'image/heic';
      }
    }
    if (_startsWith(bytes, ascii.encode('BM'))) return 'image/bmp';
    if (_startsWith(bytes, const [0x49, 0x49, 0x2A, 0x00]) ||
        _startsWith(bytes, const [0x4D, 0x4D, 0x00, 0x2A])) {
      return 'image/tiff';
    }

    return null;
  }

  static bool _startsWith(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  static const _mimeTypes = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.heic': 'image/heic',
    '.heif': 'image/heic',
    '.bmp': 'image/bmp',
    '.tif': 'image/tiff',
    '.tiff': 'image/tiff',
  };
}
