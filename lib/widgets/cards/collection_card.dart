import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/collections.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_card.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/util/async_value.dart';

class CollectionCard extends ConsumerWidget {
  final int collectionId;

  const CollectionCard({
    super.key,
    required this.collectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(
      collectionProvider(collectionId: collectionId),
    );

    return Async(
      asyncValue: collection,
      data: (collection) => CoverCard(
        title: collection.title,
        icon: const Icon(
          KoverIcons.collection,
          size: LayoutConstants.smallIcon,
        ),
        coverImage: CollectionCoverImage(collectionId: collectionId),
        onTap: () {
          CollectionSeriesRoute(collectionId: collectionId).push(context);
        },
      ),
    );
  }
}
