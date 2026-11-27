import 'dart:convert';
import 'dart:io';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/utils/annotation_image.dart';

void main() {
  group('AnnotationImage', () {
    test('keeps remote and data image sources unchanged', () async {
      const url = 'https://example.com/image.png';
      const dataUri = 'data:image/png,raw-image-data';

      expect(await AnnotationImage.toPortableSource(url), url);
      expect(await AnnotationImage.toPortableSource(dataUri), dataUri);
    });

    test('converts a picked file into a data uri', () async {
      final directory = await Directory.systemTemp.createTemp(
        'kover_annotation_image',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2];
      final file = File('${directory.path}/note.png')..writeAsBytesSync(bytes);

      final source = await AnnotationImage.toPortableSource(file.path);

      expect(source, startsWith('data:image/png;base64,'));
      expect(base64Decode(source.split(',')[1]), bytes);
    });

    test('detects the image type without a file extension', () async {
      final directory = await Directory.systemTemp.createTemp(
        'kover_annotation_image',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/note')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 1, 2]);

      final source = await AnnotationImage.toPortableSource(file.path);

      expect(source, startsWith('data:image/jpeg;base64,'));
    });

    test('inserts an image block at the current selection', () {
      final controller = quill.QuillController.basic();
      addTearDown(controller.dispose);

      AnnotationImage.insert(
        controller: controller,
        source: 'https://example.com/image.png',
      );

      expect(controller.document.toDelta().toJson(), [
        {
          'insert': {'image': 'https://example.com/image.png'},
        },
        {'insert': '\n'},
      ]);
    });

    test('rejects unsupported file contents', () async {
      final directory = await Directory.systemTemp.createTemp(
        'kover_annotation_image',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/note.unknown')
        ..writeAsBytesSync([1, 2, 3]);

      expect(
        () => AnnotationImage.toPortableSource(file.path),
        throwsUnsupportedError,
      );
    });
  });
}
