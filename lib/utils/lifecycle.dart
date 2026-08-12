import 'package:material_ui/material_ui.dart';

class LifecycleOnResumeObserver extends WidgetsBindingObserver {
  final void Function() onResume;
  LifecycleOnResumeObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
