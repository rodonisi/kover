import 'package:flutter/material.dart';

extension ColorExtensions on Color {
  String toCssRgba() {
    final red = _toArgbRange(r);
    final green = _toArgbRange(g);
    final blue = _toArgbRange(b);

    return 'rgba($red, $green, $blue, $a)';
  }

  static int _toArgbRange(double color) =>
      (color * 255.0).round().clamp(0, 255);
}
