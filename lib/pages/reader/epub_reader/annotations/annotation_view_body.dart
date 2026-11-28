import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kover/pages/reader/epub_reader/annotations/annotation_quote.dart';
import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class AnnotationViewBody extends StatelessWidget {
  const new({
    super.key,
    required this.header,
    required this.selectedText,
    required this.accentColor,
    required this.attribution,
    required this.commentHtml,
  });

  final Widget header;
  final String selectedText;
  final Color? accentColor;
  final String attribution;
  final String? commentHtml;

  @override
  Widget build(BuildContext context) {
    final commentWidget = commentHtml == null
        ? null
        : HtmlWidget(
            commentHtml!,
            renderMode: .column,
          );

    return SingleChildScrollView(
      padding: const .symmetric(
        horizontal: LayoutConstants.mediumPadding,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: LayoutConstants.mediumPadding,
        children: [
          header,
          AnnotationQuoteBlock(
            text: selectedText,
            accentColor: accentColor,
            attribution: attribution,
          ),
          ?commentWidget,
        ],
      ),
    );
  }
}
