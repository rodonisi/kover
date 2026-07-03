import 'dart:ui';

import 'package:html/dom.dart';

extension StringExtensions on String {
  bool isHtml() {
    final fragment = DocumentFragment.html(this);
    return fragment.children.isNotEmpty;
  }

  Color? toColor() {
    final stripped = replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6,8}$').hasMatch(stripped)) return null;
    final buffer = StringBuffer();
    if (stripped.length == 6) buffer.write('ff');
    buffer.write(stripped);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String get cssEscaped {
    return replaceAll('"', '\'');
  }
}
