import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';

extension EpubTextAlignmentExtensions on EpubTextAlignment {
  String get cssValue => switch (this) {
    .left => 'left',
    .right => 'right',
    .center => 'center',
    .justify => 'justify',
  };
}
