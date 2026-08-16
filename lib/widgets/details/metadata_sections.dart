import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/pages/series_detail_page/pill_run.dart';
import 'package:kover/riverpod/providers/metadata.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/details/info_widgets.dart';
import 'package:kover/widgets/details/summary.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

class MetadataWriters extends StatelessWidget {
  final MetadataViewModel metadata;

  const MetadataWriters({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (metadata.writers.isEmpty) return const SizedBox.shrink();

    return LimitedList(
      title: l.writers,
      items: metadata.writers
          .map(
            (w) => Text(
              w.name,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          )
          .toList(),
    );
  }
}

class MetadataGenres extends StatelessWidget {
  final MetadataViewModel metadata;

  const MetadataGenres({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (metadata.genres.isEmpty) return const SizedBox.shrink();

    return LimitedList(
      maxItems: 3,
      title: l.genres,
      items: metadata.genres
          .map(
            (g) => Text(
              g.name,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          )
          .toList(),
    );
  }
}

class MetadataTags extends StatelessWidget {
  final MetadataViewModel metadata;

  const MetadataTags({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (metadata.tags.isEmpty) return const SizedBox.shrink();

    return LimitedList(
      maxItems: 3,
      title: l.tags,
      items: metadata.tags
          .map(
            (t) => Text(
              t.name,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          )
          .toList(),
    );
  }
}

class SliverSummary extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({
    super.key,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) =>
          metadata.summary == null || metadata.summary!.isEmpty,
      builder: (context, metadata) {
        return Summary(summary: metadata.summary!);
      },
    );
  }
}

class SliverGenres extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.genres.isEmpty,
      builder: (context, metadata) {
        return PillRun(
          title: AppLocalizations.of(context).genres,
          items: metadata.genres
              .map((g) => PillRunItem(label: g.name))
              .toList(),
        );
      },
    );
  }
}

class SliverTags extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.tags.isEmpty,
      builder: (context, metadata) {
        return PillRun(
          title: AppLocalizations.of(context).tags,
          items: metadata.tags
              .map((t) => PillRunItem(label: t.name, icon: KoverIcons.tag))
              .toList(),
        );
      },
    );
  }
}

class SliverWriters extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.writers.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(
          title: AppLocalizations.of(context).writers,
          items: metadata.writers,
        );
      },
    );
  }
}

class SliverCoverArtists extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.coverArtists.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.coverArtists, items: metadata.coverArtists);
      },
    );
  }
}

class SliverPublishers extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.publishers.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.publishers, items: metadata.publishers);
      },
    );
  }
}

class SliverCharacters extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.characters.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.characters, items: metadata.characters);
      },
    );
  }
}

class SliverPencillers extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.pencillers.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.pencillers, items: metadata.pencillers);
      },
    );
  }
}

class SliverInkers extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.inkers.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.inkers, items: metadata.inkers);
      },
    );
  }
}

class SliverImprints extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.imprints.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.imprints, items: metadata.imprints);
      },
    );
  }
}

class SliverColorists extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.colorists.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.colorists, items: metadata.colorists);
      },
    );
  }
}

class SliverLetterers extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.letterers.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.letterers, items: metadata.letterers);
      },
    );
  }
}

class SliverEditors extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.editors.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.editors, items: metadata.editors);
      },
    );
  }
}

class SliverTranslators extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.translators.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.translators, items: metadata.translators);
      },
    );
  }
}

class SliverTeams extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.teams.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.teams, items: metadata.teams);
      },
    );
  }
}

class SliverLocations extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;

  const new({super.key, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SliverMetadataEntry(
      padding: padding,
      isEmpty: (metadata) => metadata.locations.isEmpty,
      builder: (context, metadata) {
        return PeopleRun(title: l.locations, items: metadata.locations);
      },
    );
  }
}

class _SliverMetadataEntry extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;
  final Widget Function(BuildContext context, MetadataViewModel metadata)
  builder;
  final bool Function(MetadataViewModel metadata)? isEmpty;

  const _SliverMetadataEntry({
    this.padding,
    this.isEmpty,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = MetadataScope.of(context);
    final metadata = ref.watch(metadataProvider(metadataId: id));

    return AsyncSliver(
      asyncValue: metadata,
      data: (metadata) {
        if (isEmpty != null && isEmpty!(metadata)) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverPadding(
          padding:
              padding ??
              const .only(
                top: LayoutConstants.mediumPadding,
                left: LayoutConstants.mediumPadding,
                right: LayoutConstants.mediumPadding,
              ),
          sliver: SliverToBoxAdapter(
            child: builder(context, metadata),
          ),
        );
      },
    );
  }
}

class MetadataScope extends InheritedWidget {
  const MetadataScope({
    super.key,
    required this.metadataId,
    required super.child,
  });

  final MetadataId metadataId;

  static MetadataId of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MetadataScope>();
    assert(scope != null, 'MetadataScope not found above this context');
    return scope!.metadataId;
  }

  @override
  bool updateShouldNotify(MetadataScope oldWidget) =>
      metadataId != oldWidget.metadataId;
}
