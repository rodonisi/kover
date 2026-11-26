import 'package:kover/pages/reader/epub_reader/annotations/annotation_quote.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

/// View-mode body. Header, quote, attribution and comment share one scroll view.
class AnnotationViewBody extends StatelessWidget {
  const new({
    super.key,
    this.header,
    required this.selectedText,
    required this.accentColor,
    required this.attribution,
    required this.comment,
  });

  final Widget? header;
  final String selectedText;
  final Color? accentColor;
  final String? attribution;
  final String comment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: LayoutConstants.mediumPadding,
        children: [
          ?header,
          AnnotationQuoteBlock(
            text: selectedText,
            accentColor: accentColor,
            attribution: attribution,
            scrollable: false,
          ),
          Text(comment),
        ],
      ),
    );
  }
}
