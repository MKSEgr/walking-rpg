import 'package:flutter/widgets.dart';

class NavigationChromeInsets extends InheritedWidget {
  const NavigationChromeInsets({
    super.key,
    required this.bottomDockInset,
    required super.child,
  });

  static const double compactBottomDockInset = 82;

  final double bottomDockInset;

  static double bottomDockInsetOf(BuildContext context) {
    final NavigationChromeInsets? scope = context
        .dependOnInheritedWidgetOfExactType<NavigationChromeInsets>();
    return scope?.bottomDockInset ?? compactBottomDockInset;
  }

  @override
  bool updateShouldNotify(NavigationChromeInsets oldWidget) {
    return bottomDockInset != oldWidget.bottomDockInset;
  }
}
