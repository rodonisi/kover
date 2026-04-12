import 'dart:ui';

import 'package:html/dom.dart';

extension StringExtensions on String {
  bool isHtml() {
    final fragment = DocumentFragment.html(this);
    return fragment.children.isNotEmpty;
  }

  Color toColor() {
    final buffer = StringBuffer();
    if (length == 6 || length == 7) buffer.write('ff');
    buffer.write(replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
