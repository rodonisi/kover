import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/epub_reader_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/extensions/epub_theme.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/settings/option_container.dart';
import 'package:kover/widgets/util/async_value.dart';

class ThemePicker extends ConsumerWidget {
  final int seriesId;
  const ThemePicker({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final provider = epubReaderSettingsProvider(seriesId: seriesId);
    final theme = ref.watch(provider.select((s) => s.whenData((s) => s.theme)));

    return Async(
      asyncValue: theme,
      data: (data) {
        return OptionContainer(
          icon: KoverIcons.theme,
          title: l.theme,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: .horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                  ),
                  child: Row(
                    spacing: LayoutConstants.largePadding,
                    mainAxisAlignment: .center,
                    children: [
                      Tooltip(
                        message: l.matchAppTheme,
                        child: _Selected(
                          isSelected: data == null,
                          child: _AppThemeOption(
                            onTap: () async {
                              await ref.read(provider.notifier).setTheme(null);
                            },
                          ),
                        ),
                      ),
                      ...EpubTheme.values.map((t) {
                        final isSelected = t == data;
                        return Tooltip(
                          message: switch (t) {
                            .light => l.light,
                            .sepia => l.sepia,
                            .dark => l.dark,
                          },
                          child: _Selected(
                            isSelected: isSelected,
                            child: Theme(
                              data: t.data,
                              child: _ThemePreview(
                                onTap: () async {
                                  await ref.read(provider.notifier).setTheme(t);
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AppThemeOption extends StatelessWidget {
  final VoidCallback? onTap;

  const _AppThemeOption({this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: LayoutConstants.largestIcon,
      child: Card(
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surface,
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: _DiagonalLinePainter(
              lineColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  final Color lineColor;
  final double strokeWidth = 3.0;

  _DiagonalLinePainter({
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalLinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _ThemePreview extends StatelessWidget {
  final VoidCallback? onTap;

  const _ThemePreview({this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: LayoutConstants.largestIcon,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surface,
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              'Aa',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Selected extends StatelessWidget {
  final bool isSelected;
  final Widget child;

  const _Selected({required this.isSelected, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isSelected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3.0,
                ),
                borderRadius: .circular(LayoutConstants.smallBorderRadius),
              ),
            ),
          ),
      ],
    );
  }
}
