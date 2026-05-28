import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

sealed class KoverIcons {
  static const IconData verticalReader = LucideIcons.moveVertical;
  static const IconData horizontalReader = LucideIcons.moveHorizontal;
  static const IconData twoPageReader = LucideIcons.columns2;

  static const IconData readingDirectionLTR = LucideIcons.chevronsRight;
  static const IconData readingDirectionRTL = LucideIcons.chevronsLeft;

  static const IconData fitWidth = LucideIcons.chevronsLeftRight;
  static const IconData fitHeight = LucideIcons.chevronsUpDown;
  static const IconData fitContain = LucideIcons.fullscreen;

  static const IconData progressBar = LucideIcons.minus;

  static const IconData safeArea = LucideIcons.expand;

  static const IconData save = LucideIcons.save;
  static const IconData reset = LucideIcons.rotateCcw;

  static const IconData ascending = LucideIcons.arrowDownNarrowWide;
  static const IconData descending = LucideIcons.arrowDownWideNarrow;

  static const IconData collection = LucideIcons.layoutGrid;
}
