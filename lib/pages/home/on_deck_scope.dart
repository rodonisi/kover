import 'package:flutter/widgets.dart';

class OnDeckScope extends InheritedWidget {
  const OnDeckScope({super.key, required super.child});

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OnDeckScope>() != null;
  }

  @override
  bool updateShouldNotify(OnDeckScope oldWidget) => false;
}
