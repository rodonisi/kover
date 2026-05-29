import 'package:flutter/material.dart';
import 'package:kover/models/collection_model.dart';
import 'package:kover/widgets/cards/collection_card.dart';
import 'package:kover/widgets/lists/adaptive_sliver_grid.dart';

class CollectionsSliverGrid extends StatelessWidget {
  const CollectionsSliverGrid({
    super.key,
    required this.collections,
  });

  final List<CollectionModel> collections;

  @override
  Widget build(BuildContext context) {
    return AdaptiveSliverGrid(
      itemCount: collections.length,
      builder: (context, index) {
        final collection = collections[index];
        return CollectionCard(collectionId: collection.id);
      },
    );
  }
}
