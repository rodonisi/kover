import 'package:kover/models/read_direction.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

/// A horizontal [SequentialPagesLayout] that supports both reading directions.
class const HorizontalPageLayout({
  final ReadDirection readDirection = .leftToRight,
  super.spacing,
  super.margin,
  super.fitMode,
  super.crossAxisAlignment,
}) extends SequentialPagesLayout {
  this : super(scrollDirection: .horizontal);

  int? Function(Rect, List<Rect>, PdfViewerController)?
  get calculateCurrentPageNumber =>
      readDirection == .leftToRight ? null : _calculateMostVisiblePageNumber;

  @override
  PdfPageLayout resolve(PdfPageLayoutContext context) {
    final layout = super.resolve(context);
    if (readDirection == .leftToRight) return layout;

    final width = layout.documentSize.width;
    return PdfPageLayout(
      pageLayouts: [
        for (final rect in layout.pageLayouts)
          Rect.fromLTRB(
            width - rect.right,
            rect.top,
            width - rect.left,
            rect.bottom,
          ),
      ],
      documentSize: layout.documentSize,
      margin: layout.margin,
      fitMode: layout.fitMode,
      primaryAxis: layout.primaryAxis,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HorizontalPageLayout &&
      other.readDirection == readDirection &&
      super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, readDirection);
}

int? _calculateMostVisiblePageNumber(
  Rect visibleRect,
  List<Rect> pageRects,
  PdfViewerController controller,
) {
  final currentPage = controller.pageNumber;

  if (pageRects.isEmpty) return controller.pageNumber;

  final center = visibleRect.center;
  var bestPage = 1;
  var bestArea = -1.0;
  var bestDistance = double.infinity;

  for (var i = 0; i < pageRects.length; i++) {
    final rect = pageRects[i];
    final intersection = rect.intersect(visibleRect);
    final area = intersection.isEmpty
        ? 0.0
        : intersection.size.width * intersection.size.height;
    final distance = (rect.center - center).distanceSquared;
    final page = i + 1;

    if (area > bestArea) {
      bestPage = page;
      bestArea = area;
      bestDistance = distance;
    } else if (area == bestArea) {
      final isCurrent = page == currentPage;
      final bestIsCurrent = bestPage == currentPage;
      if (isCurrent || (!bestIsCurrent && distance < bestDistance)) {
        bestPage = page;
        bestDistance = distance;
      }
    }
  }

  return bestPage;
}
