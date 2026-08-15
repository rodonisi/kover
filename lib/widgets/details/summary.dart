import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/utils/extensions/string.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class Summary extends StatelessWidget {
  final String? summary;

  const new({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (summary == null || summary!.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: .min,
      spacing: LayoutConstants.smallPadding,
      crossAxisAlignment: .start,
      children: <Widget>[
        Text(
          l.summary,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        _SummaryContent(summary: summary!),
      ],
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final String summary;

  const new({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final contentWidget = summary.isHtml()
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.smallPadding,
            ),
            child: HtmlWidget(
              summary,
              renderMode: .column,
            ),
          )
        : Markdown(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.smallPadding,
            ),
            data: summary,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          );

    return AnimatedSize(
      duration: 100.ms,
      alignment: Alignment.topCenter,
      child: contentWidget,
    );
  }
}
