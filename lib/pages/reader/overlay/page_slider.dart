import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/utils/layout_constants.dart';

class PageSlider extends HookConsumerWidget {
  final int seriesId;
  final int? chapterId;
  final void Function(int page)? onJumpToPage;

  const PageSlider({
    super.key,
    required this.seriesId,
    required this.chapterId,
    this.onJumpToPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPages =
        ref.watch(
          readerProvider(seriesId: seriesId, chapterId: chapterId).select(
            (state) => state.value?.totalPages,
          ),
        ) ??
        1;
    final navState = ref.watch(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ),
    );
    final currentPage = navState.currentPage;
    final sliderValue = useState(currentPage.toDouble());

    useEffect(() {
      sliderValue.value = currentPage.toDouble();
      return null;
    }, [currentPage]);

    return Row(
      mainAxisAlignment: .spaceEvenly,
      children: [
        const SizedBox.square(dimension: LayoutConstants.mediumPadding),
        Text('${navState.currentPage + 1}'),
        Expanded(
          child: Slider(
            value: sliderValue.value,
            min: 0,
            max: totalPages.toDouble(),
            divisions: totalPages > 1 ? totalPages - 1 : null,
            label: '${sliderValue.value.floor() + 1}',
            onChanged: (value) {
              sliderValue.value = value;
            },
            onChangeEnd: (value) {
              onJumpToPage?.call(
                sliderValue.value.floor(),
              );
            },
          ),
        ),
        Text('$totalPages'),
        const SizedBox.square(dimension: LayoutConstants.mediumPadding),
      ],
    );
  }
}
