import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/utils/logging.dart';
import 'package:kover/widgets/async_value.dart';
import 'package:kover/widgets/measured_widget.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

class VerticalContinuousReader extends ConsumerStatefulWidget {
  final int seriesId;
  final int chapterId;

  const VerticalContinuousReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  ConsumerState<VerticalContinuousReader> createState() =>
      _VerticalContinuousReaderState();
}

/// How many pages on each side of the current page render their image.
/// Pages outside this window are replaced with a same-height coloured
/// placeholder so the decoded bitmap is not kept in memory.
const int _visiblePageRadius = 3;

class _VerticalContinuousReaderState
    extends ConsumerState<VerticalContinuousReader> {
  late ScrollController _scrollController;
  late SliverObserverController _observerController;
  final Map<int, double> _cachedHeights = {};
  BuildContext? _sliverContext;
  int? _totalPages;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  /// Emit last-page progress when scrolled to bottom edge.
  void _handleScrollEnd() {
    final pos = _scrollController.position;
    if (pos.atEdge &&
        pos.pixels >= pos.maxScrollExtent &&
        _totalPages != null) {
      final lastIndex = _totalPages! - 1;
      final navProvider = readerNavigationProvider(
        seriesId: widget.seriesId,
        chapterId: widget.chapterId,
      );
      if (ref.read(navProvider).currentPage != lastIndex) {
        log.d('Scrolled to bottom edge, ensuring last page $lastIndex');
        ref
            .read(navProvider.notifier)
            .jumpToPage(lastIndex, fromObserver: true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollEnd);
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScrollEnd);

    // Get initial page from navigation state
    final initialPage = ref
        .read(
          readerNavigationProvider(
            seriesId: widget.seriesId,
            chapterId: widget.chapterId,
          ),
        )
        .currentPage;

    _currentPage = initialPage;

    _observerController =
        SliverObserverController(
            controller: _scrollController,
          )
          ..cacheJumpIndexOffset = false
          ..initialIndexModelBlock = () =>
              ObserverIndexPositionModel(index: initialPage);
  }

  void _handleObserve(ObserveModel model) {
    if (model is! ListViewObserveModel) return;

    final firstVisibleIndex = model.firstChild?.index;
    if (firstVisibleIndex == null) return;
    log.d('First visible index: $firstVisibleIndex');

    final navProvider = readerNavigationProvider(
      seriesId: widget.seriesId,
      chapterId: widget.chapterId,
    );

    final currentPage = ref.read(navProvider).currentPage;
    if (firstVisibleIndex != currentPage) {
      ref
          .read(navProvider.notifier)
          .jumpToPage(firstVisibleIndex, fromObserver: true);
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    _sliverContext ??= context;

    final isVisible = (index - _currentPage).abs() <= _visiblePageRadius;

    return _KeepAlivePage(
      key: ValueKey(index),
      child: Consumer(
        builder: (context, ref, _) {
          final imageCacheWidth =
              (MediaQuery.of(context).size.width *
                      MediaQuery.of(context).devicePixelRatio)
                  .toInt();
          // Outside the visible window and height already known: swap the
          // decoded bitmap for a same-height coloured placeholder so the
          // image is not kept in memory.
          if (!isVisible && _cachedHeights.containsKey(index)) {
            return SizedBox(
              height: _cachedHeights[index]!,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            );
          }

          final image = ref.watch(
            imagePageProvider(
              chapterId: widget.chapterId,
              page: index,
            ),
          );

          if (_cachedHeights.containsKey(index)) {
            return SizedBox(
              height: _cachedHeights[index]!,
              child: Async(
                asyncValue: image,
                data: (data) => Image.memory(
                  data.data,
                  fit: BoxFit.fitWidth,
                  cacheWidth: imageCacheWidth,
                ),
              ),
            );
          }

          return Async(
            asyncValue: image,
            data: (data) => MeasuredWidget(
              onSizeMeasured: (size) {
                if (size.height > 0) {
                  log.d('Caching height for page $index: ${size.height}');
                  _cachedHeights[index] = size.height;
                }
              },
              child: Image.memory(
                data.data,
                fit: BoxFit.fitWidth,
                cacheWidth: imageCacheWidth,
              ),
            ),
            loading: () {
              return AspectRatio(
                aspectRatio: 5 / 8,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      imageReaderSettingsProvider(seriesId: widget.seriesId),
    );

    ref.listen(
      readerNavigationProvider(
        seriesId: widget.seriesId,
        chapterId: widget.chapterId,
      ),
      (previous, next) async {
        setState(() {
          _totalPages ??= next.totalPages;
          _currentPage = next.currentPage;
        });

        if (!_scrollController.hasClients ||
            previous?.currentPage == next.currentPage) {
          return;
        }

        // If the new page matches what we just observed from scrolling, ignore it
        // This prevents the circular feedback loop
        if (next.fromObserver) {
          log.d('Ignoring observer update');
          return;
        }

        final isSequential =
            previous != null &&
            (next.currentPage - previous.currentPage).abs() == 1;

        if (isSequential) {
          log.d('Animating to page $next');
          await _observerController.animateTo(
            index: next.currentPage,
            duration: 200.ms,
            curve: Curves.easeInOut,
          );
        } else {
          log.d('Jumping to page $next');
          await _observerController.jumpTo(index: next.currentPage);
        }
      },
    );

    ref.listen(
      imageReaderSettingsProvider(seriesId: widget.seriesId).select(
        (settings) => settings.value?.verticalReaderPadding,
      ),
      (previous, next) {
        if (previous != next) {
          setState(() {
            _cachedHeights.clear();
          });
        }
      },
    );

    return SliverViewObserver(
      controller: _observerController,
      sliverContexts: () => [?_sliverContext],
      onObserve: _handleObserve,
      child: CustomScrollView(
        controller: _scrollController,
        cacheExtent: MediaQuery.of(context).size.height * 5,
        scrollBehavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
        ),
        slivers: [
          AsyncSliver(
            asyncValue: settings,
            data: (settings) => SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: settings.verticalReaderPadding,
              ),
              sliver: SliverList.separated(
                addAutomaticKeepAlives: true,
                itemCount: _totalPages,
                itemBuilder: _buildItem,
                separatorBuilder: (context, index) =>
                    SizedBox(height: settings.verticalReaderGap),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({super.key, required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
