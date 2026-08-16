import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/models/enums/publication_status.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/pages/series_detail_page/pill_run.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/details/info_widgets.dart';
import 'package:kover/widgets/details/summary.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:material_ui/material_ui.dart';

abstract interface class MetadataViewModel {
  String? get summary;
  int? get releaseYear;
  PublicationStatus get publicationStatus;
  List<GenreModel> get genres;
  List<TagModel> get tags;
  List<PersonModel> get writers;
  List<PersonModel> get coverArtists;
  List<PersonModel> get publishers;
  List<PersonModel> get characters;
  List<PersonModel> get pencillers;
  List<PersonModel> get inkers;
  List<PersonModel> get imprints;
  List<PersonModel> get colorists;
  List<PersonModel> get letterers;
  List<PersonModel> get editors;
  List<PersonModel> get translators;
  List<PersonModel> get teams;
  List<PersonModel> get locations;
}

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

class MetadataSections extends StatelessWidget {
  final AsyncValue<MetadataViewModel> asyncValue;

  const MetadataSections({super.key, required this.asyncValue});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Async(
      asyncValue: asyncValue,
      data: (metadata) {
        final sections = <Widget>[
          if (metadata.summary != null && metadata.summary!.isNotEmpty)
            Summary(summary: metadata.summary),
          if (metadata.genres.isNotEmpty)
            PillRun(
              title: l.genres,
              items: metadata.genres
                  .map(
                    (g) => PillRunItem(label: g.name),
                  )
                  .toList(),
            ),
          if (metadata.tags.isNotEmpty)
            PillRun(
              title: l.tags,
              items: metadata.tags
                  .map((g) => PillRunItem(label: g.name, icon: KoverIcons.tag))
                  .toList(),
            ),
          if (metadata.writers.isNotEmpty)
            PeopleRun(title: l.writers, items: metadata.writers),
          if (metadata.coverArtists.isNotEmpty)
            PeopleRun(title: l.coverArtists, items: metadata.coverArtists),
          if (metadata.publishers.isNotEmpty)
            PeopleRun(title: l.publishers, items: metadata.publishers),
          if (metadata.characters.isNotEmpty)
            PeopleRun(title: l.characters, items: metadata.characters),
          if (metadata.pencillers.isNotEmpty)
            PeopleRun(title: l.pencillers, items: metadata.pencillers),
          if (metadata.inkers.isNotEmpty)
            PeopleRun(title: l.inkers, items: metadata.inkers),
          if (metadata.imprints.isNotEmpty)
            PeopleRun(title: l.imprints, items: metadata.imprints),
          if (metadata.colorists.isNotEmpty)
            PeopleRun(title: l.colorists, items: metadata.colorists),
          if (metadata.letterers.isNotEmpty)
            PeopleRun(title: l.letterers, items: metadata.letterers),
          if (metadata.editors.isNotEmpty)
            PeopleRun(title: l.editors, items: metadata.editors),
          if (metadata.translators.isNotEmpty)
            PeopleRun(title: l.translators, items: metadata.translators),
          if (metadata.teams.isNotEmpty)
            PeopleRun(title: l.teams, items: metadata.teams),
          if (metadata.locations.isNotEmpty)
            PeopleRun(title: l.locations, items: metadata.locations),
        ];
        if (sections.isEmpty) return const SizedBox.shrink();

        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: LayoutConstants.mediumPadding,
          children: sections,
        );
      },
    );
  }
}
