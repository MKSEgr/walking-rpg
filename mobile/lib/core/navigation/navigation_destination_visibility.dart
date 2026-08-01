import 'package:flutter/widgets.dart';

class NavigationDestinationVisibility extends InheritedWidget {
  const NavigationDestinationVisibility({
    super.key,
    required this.isVisible,
    required super.child,
  });

  final bool isVisible;

  static bool of(BuildContext context) {
    final NavigationDestinationVisibility? scope = context
        .dependOnInheritedWidgetOfExactType<NavigationDestinationVisibility>();
    return scope?.isVisible ?? true;
  }

  @override
  bool updateShouldNotify(NavigationDestinationVisibility oldWidget) {
    return isVisible != oldWidget.isVisible;
  }
}
