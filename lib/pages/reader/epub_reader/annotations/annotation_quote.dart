import 'package:kover/utils/constants/layout_constants.dart';
import 'package:material_ui/material_ui.dart';

/// Selected text card with attribution below.
class AnnotationQuoteBlock extends StatelessWidget {
  const new({
    super.key,
    required this.text,
    required this.accentColor,
    required this.attribution,
    required this.scrollable,
  });

  final String text;
  final Color? accentColor;
  final String attribution;

  /// When true the card expands to its flex share and scrolls internally.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final card = AnnotationQuoteCard(
      text: text,
      accentColor: accentColor,
      scrollable: scrollable,
    );

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: LayoutConstants.smallerPadding,
      children: [
        if (scrollable) Flexible(child: card) else card,
        AnnotationAttribution(text: attribution),
      ],
    );
  }
}

/// Highlight-colored quote card. Scrolls internally only in edit mode.
class AnnotationQuoteCard extends StatelessWidget {
  const new({
    super.key,
    required this.text,
    required this.accentColor,
    required this.scrollable,
  });

  final String text;
  final Color? accentColor;
  final bool scrollable;

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
          border: switch (accentColor) {
            final color? => BorderDirectional(
              start: BorderSide(
                color: color,
                width: LayoutConstants.smallerPadding,
              ),
            ),
            null => null,
          },
        ),
        child: scrollable ? SingleChildScrollView(child: content) : content,
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
