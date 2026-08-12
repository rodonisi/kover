import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:kover/utils/headless_measure_pipeline.dart';

/// The widget tree measured by the [HeadlessMeasurePipeline] for a single
/// image.
class ImageMeasureRoot extends StatelessWidget {
  final ui.Image image;
  final double horizontalPadding;

  const ImageMeasureRoot({
    super.key,
    required this.image,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MeasureTarget(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: RawImage(
              image: image,
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ],
    );
  }
}
