import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/utils/extensions/string.dart';
import 'package:kover/utils/layout_constants.dart';

class Summary extends HookConsumerWidget {
  final String? summary;

  const Summary({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = useState(true);

    if (summary == null || summary!.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: .min,
      spacing: LayoutConstants.smallPadding,
      children: [
        Row(
          mainAxisAlignment: .spaceBetween,
          crossAxisAlignment: .center,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextButton(
              onPressed: () => collapsed.value = !collapsed.value,
              child: Text(
                collapsed.value ? 'Show More' : 'Show Less',
              ),
            ),
          ],
        ),
        _SummaryContent(summary: summary!, collapsed: collapsed.value),
      ],
    );
  }
}

class _SummaryContent extends HookWidget {
  final String summary;
  final bool collapsed;

  const _SummaryContent({
    required this.summary,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    final height = useMemoized(() => collapsed ? 100.0 : double.infinity, [
      collapsed,
    ]);

    final contentWidget = summary.isHtml()
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.smallPadding,
            ),
            // required due to HtmlWidget being rendered in a column which really wants to render its whole content and
            // show past the overflow
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: HtmlWidget(
                summary,
                renderMode: .column,
              ),
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
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: collapsed
            ? ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.7, 0.95],
                  ).createShader(bounds);
                },
                blendMode: .dstIn,
                child: contentWidget,
              )
            : contentWidget,
      ),
    );
  }
}
