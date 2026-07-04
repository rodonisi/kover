import 'package:flutter/material.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/widgets/cards/series_card.dart';
import 'package:kover/widgets/lists/adaptive_sliver_grid.dart';

class SeriesSliverGrid extends StatelessWidget {
  final List<SeriesModel> series;
  final int? rowCount;
  final void Function(int crossAxisCount)? onCrossAxisCountChanged;

  const SeriesSliverGrid({
    super.key,
    required this.series,
    this.rowCount,
    this.onCrossAxisCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveSliverGrid(
      itemCount: series.length,
      rowCount: rowCount,
      onCrossAxisCountChanged: onCrossAxisCountChanged,
      builder: (context, index) {
        final series = this.series[index];
        return SeriesCard(seriesId: series.id);
      },
    );
  }
}
