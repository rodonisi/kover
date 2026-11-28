import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

class AnnotationQuoteBlock extends StatelessWidget {
  const new({
    super.key,
    required this.text,
    required this.accentColor,
    required this.attribution,
  });

  final String text;
  final Color? accentColor;
  final String attribution;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: LayoutConstants.smallerPadding,
      children: [
        AnnotationQuoteCard(text: text, accentColor: accentColor),
        AnnotationAttribution(text: attribution),
      ],
    );
  }
}

class AnnotationQuoteCard extends StatelessWidget {
  const new({
    super.key,
    required this.text,
    required this.accentColor,
  });

  final String text;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: LayoutConstants.mediumEdgeInsets,
      child: SizedBox(
        width: .infinity,
        child: Text(text),
      ),
    );

    return Card.filled(
      margin: .zero,
      clipBehavior: .antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: accentColor != null
              ? BorderDirectional(
                  start: BorderSide(
                    color: accentColor!,
                    width: LayoutConstants.smallerPadding,
                  ),
                )
              : null,
        ),
        child: content,
      ),
    );
  }
}

class AnnotationAttribution extends StatelessWidget {
  const new({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: .centerEnd,
      child: Text(
        text,
        textAlign: .end,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
