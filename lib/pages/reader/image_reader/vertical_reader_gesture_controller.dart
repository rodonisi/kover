import 'dart:math' as math;

import 'package:flutter/material.dart';

class VerticalReaderGestureController extends ChangeNotifier {
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  VerticalReaderGestureController() : _scale = _minScale;

  Size _viewportSize = Size.zero;
  double _scale;
  double _horizontalTranslation = 0.0;

  double get scale => _scale;
  Offset get translation => Offset(_horizontalTranslation, 0.0);
  double get verticalScrollPadding =>
      _viewportSize.height * (_scale - _minScale) / (2 * _scale);

  void configureViewport(Size viewportSize) {
    if (_viewportSize == viewportSize) return;

    _viewportSize = viewportSize;
    _horizontalTranslation = _clampHorizontalTranslation(
      _horizontalTranslation,
    );
    notifyListeners();
  }

  void panHorizontally(double delta) {
    final nextTranslation = _clampHorizontalTranslation(
      _horizontalTranslation + delta,
    );
    if (nextTranslation != _horizontalTranslation) {
      _horizontalTranslation = nextTranslation;
      notifyListeners();
    }
  }

  double visualScrollOffset(double scrollOffset) => _scale * scrollOffset;

  double zoomViewport({
    required double scaleFactor,
    required Offset focalPoint,
    required Offset focalPointDelta,
    required double visualScrollOffset,
  }) {
    if (!scaleFactor.isFinite || scaleFactor <= 0) {
      return visualScrollOffset;
    }

    final nextScale = (_scale * scaleFactor)
        .clamp(_minScale, _maxScale)
        .toDouble();
    final appliedFactor = nextScale / _scale;
    final previousFocalPoint = focalPoint - focalPointDelta;
    final viewportCenter = _viewportSize.center(Offset.zero);
    final nextHorizontalTranslation = _clampHorizontalTranslation(
      focalPointDelta.dx +
          _horizontalTranslation * appliedFactor +
          (previousFocalPoint.dx - viewportCenter.dx) * (1 - appliedFactor),
      scale: nextScale,
    );

    if (_scale != nextScale ||
        _horizontalTranslation != nextHorizontalTranslation) {
      _scale = nextScale;
      _horizontalTranslation = nextHorizontalTranslation;
      notifyListeners();
    }

    return appliedFactor *
            (visualScrollOffset + previousFocalPoint.dy - viewportCenter.dy) +
        viewportCenter.dy -
        focalPoint.dy;
  }

  double _clampHorizontalTranslation(double translation, {double? scale}) {
    final effectiveScale = scale ?? _scale;
    final overflow = math.max(
      0.0,
      (_viewportSize.width * effectiveScale - _viewportSize.width) / 2,
    );
    return translation.clamp(-overflow, overflow).toDouble();
  }
}
