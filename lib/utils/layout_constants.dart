import 'package:flutter/rendering.dart';

sealed class LayoutConstants {
  static const double smallerPadding = 4.0;
  static const double smallPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 32.0;
  static const double largerPadding = 64.0;

  static const EdgeInsets smallerEdgeInsets = EdgeInsets.all(smallerPadding);
  static const EdgeInsets smallEdgeInsets = EdgeInsets.all(smallPadding);
  static const EdgeInsets mediumEdgeInsets = EdgeInsets.all(mediumPadding);
  static const EdgeInsets largeEdgeInsets = EdgeInsets.all(largePadding);
  static const EdgeInsets largerEdgeInsets = EdgeInsets.all(largerPadding);

  static const double smallerIcon = 12.0;
  static const double smallIcon = 16.0;
  static const double mediumIcon = 24.0;
  static const double largeIcon = 32.0;
  static const double largerIcon = 48.0;
  static const double largestIcon = 64.0;

  static const double chapterCardAspectRatio = 3 / 5;
  static const double coverAspectRatio = 2 / 3;

  static const double smallestBorderRadius = 4.0;
  static const double smallerBorderRadius = 8.0;
  static const double smallBorderRadius = 12.0;
  static const double mediumBorderRadius = 16.0;
  static const double largeBorderRadius = 32.0;
  static const double largerBorderRadius = 64.0;
}

sealed class Breakpoints {
  static const double compact = 600.0;
  static const double medium = 840.0;
  static const double expanded = 1200.0;
  static const double large = 1600.0;
}
