import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/utils/extensions/string.dart';

class SeriesInfoBackground extends ConsumerWidget {
  final String? primaryColor;
  final String? secondaryColor;

  const SeriesInfoBackground({
    super.key,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: 0.2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: .topLeft,
            end: .bottomRight,
            colors: [
              if (primaryColor != null) primaryColor!.toColor(),
              if (secondaryColor != null) secondaryColor!.toColor(),
            ],
          ),
        ),
      ),
    );
  }
}
