import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class RenderHtml extends StatelessWidget {
  final String html;
  final WidgetFactory Function() factoryBuilder;
  const new({super.key, required this.html, required this.factoryBuilder});

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      factoryBuilder: factoryBuilder,
    );
  }
}
