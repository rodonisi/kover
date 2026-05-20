import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
    final navState = ref.watch(
      readerNavigationProvider(
        seriesId: seriesId,
        chapterId: chapterId,
      ),
    );
    final max = navState.totalPages - 1;
    final divisions = max > 0 ? max : null;
    final currentPage = navState.currentPage.clamp(0, max);
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
            max: max.toDouble(),
            divisions: divisions,
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
        Text('${navState.totalPages}'),
        const SizedBox.square(dimension: LayoutConstants.mediumPadding),
      ],
    );
  }
}
