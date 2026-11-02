import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kover/pages/reader/epub_reader/paginated_epub_page/css_engine.dart';

class RenderHtml extends StatelessWidget {
  final String html;
  final WidgetFactory Function() factoryBuilder;
  final CssEngine cssEngine;
  final TextStyle? textStyle;
  const new({
    super.key,
    required this.html,
    required this.factoryBuilder,
    required this.cssEngine,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      factoryBuilder: factoryBuilder,
      customStylesBuilder: (element) => cssEngine.stylesFor(element),
      textStyle: textStyle,
      rebuildTriggers: [cssEngine.stylesRevision],
    );
  }
}
