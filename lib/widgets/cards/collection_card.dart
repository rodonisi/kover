import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/models/collection_model.dart';
import 'package:kover/riverpod/providers/collections.dart';
import 'package:kover/riverpod/providers/router.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/cards/cover_image.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CollectionCard extends ConsumerWidget {
  const CollectionCard({
    super.key,
    required this.collection,
  });

  final CollectionModel collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = ref.watch(
      collectionCoverProvider(collectionId: collection.id),
    );

    return Card.filled(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => CollectionSeriesRoute(collectionId: collection.id).push(
          context,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Async(
                asyncValue: cover,
                data: (image) => PlaceholderCoverImage(image: image),
              ),
            ),
            Padding(
              padding: LayoutConstants.smallEdgeInsets,
              child: Row(
                spacing: LayoutConstants.smallPadding,
                children: [
                  const Icon(
                    LucideIcons.layoutGrid,
                    size: LayoutConstants.smallIcon,
                  ),
                  Expanded(
                    child: Text(
                      collection.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
