import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/want_to_read.dart';
import 'package:kover/utils/extensions/int.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LimitedList extends StatelessWidget {
  final String title;
  final List<String> items;
  const LimitedList({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final display = Set.from(items).take(3);
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: LayoutConstants.mediumPadding,
          children: [
            for (final writer in display)
              Text(writer, style: Theme.of(context).textTheme.labelMedium),

            if (display.length < items.length)
              Text(
                '+${items.length - display.length} more',
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
      ],
    );
  }
}

class WantToReadToggle extends ConsumerWidget {
  final int seriesId;
  const WantToReadToggle({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wantToRead = ref.watch(wantToReadProvider(seriesId: seriesId));

    return Async(
      asyncValue: wantToRead,
      data: (data) {
        return IconButton(
          icon: Icon(data ? LucideIcons.star : LucideIcons.starOff),
          color: data ? Theme.of(context).colorScheme.primary : null,
          onPressed: () async {
            final notifier = ref.read(
              wantToReadProvider(seriesId: seriesId).notifier,
            );
            await (data ? notifier.remove() : notifier.add());
          },
        );
      },
    );
  }
}

class WordCount extends StatelessWidget {
  final int wordCount;

  const WordCount({
    super.key,
    required this.wordCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      spacing: LayoutConstants.smallPadding,
      children: [
        const Icon(
          LucideIcons.fileText,
          size: LayoutConstants.smallIcon,
        ),
        Text(
          '${wordCount.prettyInt()} words',
        ),
      ],
    );
  }
}

class ReleaseYear extends StatelessWidget {
  final int releaseYear;
  const ReleaseYear({
    super.key,
    required this.releaseYear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      spacing: LayoutConstants.smallPadding,
      children: [
        const Icon(
          LucideIcons.calendar,
          size: LayoutConstants.smallIcon,
        ),
        Text(releaseYear.toString()),
      ],
    );
  }
}

class RemainingHours extends StatelessWidget {
  final double hours;

  const RemainingHours({
    super.key,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      spacing: LayoutConstants.smallPadding,
      children: [
        const Icon(
          LucideIcons.clock,
          size: LayoutConstants.smallIcon,
        ),
        Text(
          '~${hours.toStringAsFixed(1)} hours',
        ),
      ],
    );
  }
}

class Pages extends StatelessWidget {
  final int pages;
  const Pages({
    super.key,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      spacing: LayoutConstants.smallPadding,
      children: [
        const Icon(
          LucideIcons.fileStack,
          size: LayoutConstants.smallIcon,
        ),
        Text('${pages.prettyInt()} pages'),
      ],
    );
  }
}
