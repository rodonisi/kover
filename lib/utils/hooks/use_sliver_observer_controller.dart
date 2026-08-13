import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

class SliverObserverControllerHook extends Hook<SliverObserverController> {
  final ScrollController? controller;
  final int? initialIndex;

  const SliverObserverControllerHook({this.controller, this.initialIndex});

  @override
  SliverObserverControllerHookState createState() =>
      SliverObserverControllerHookState();
}

class SliverObserverControllerHookState
    extends HookState<SliverObserverController, SliverObserverControllerHook> {
  late final SliverObserverController controller;

  @override
  void initHook() {
    super.initHook();
    controller = SliverObserverController(controller: hook.controller)
      ..initialIndexModelBlock = hook.initialIndex != null
          ? () => ObserverIndexPositionModel(index: hook.initialIndex!)
          : null
      ..cacheJumpIndexOffset = false;
  }

  @override
  SliverObserverController build(BuildContext context) => controller;
}

SliverObserverController useSliverObserverController({
  ScrollController? controller,
  int? initialIndex,
}) => use(
  SliverObserverControllerHook(
    controller: controller,
    initialIndex: initialIndex,
  ),
);
