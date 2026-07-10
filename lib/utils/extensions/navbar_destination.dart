import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/riverpod/providers/settings/general_settings.dart';
import 'package:kover/utils/constants/kover_icons.dart';

extension NavbarDestinationsExtension on NavbarDestinations {
  IconData get icon {
    return switch (this) {
      .home => KoverIcons.home,
      .allSeries => KoverIcons.series,
      .wantToRead => KoverIcons.wantToRead,
      .collections => KoverIcons.collection,
      .readingLists => KoverIcons.readingList,
    };
  }

  String getLabel(AppLocalizations l) {
    return switch (this) {
      .home => l.home,
      .allSeries => l.allSeries,
      .wantToRead => l.wantToRead,
      .collections => l.collections,
      .readingLists => l.readingLists,
    };
  }

  GoRouteData get route {
    return switch (this) {
      .home => const HomeRoute(),
      .allSeries => const AllSeriesRoute(),
      .wantToRead => const WantToReadRoute(),
      .collections => const CollectionsRoute(),
      .readingLists => const ReadingListsRoute(),
    };
  }
}
