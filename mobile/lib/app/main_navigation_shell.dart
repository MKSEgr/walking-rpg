import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    required this.home,
    required this.platform,
    this.onDestinationChanged,
  });

  final Widget home;
  final Widget platform;
  final ValueChanged<int>? onDestinationChanged;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[widget.home, widget.platform],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.walkingRpgPalette.panelBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: context.walkingRpgPalette.shadow,
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                if (index == _selectedIndex) {
                  return;
                }
                setState(() {
                  _selectedIndex = index;
                });
                widget.onDestinationChanged?.call(index);
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  key: Key('navigation-home'),
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Экспедиция',
                ),
                NavigationDestination(
                  key: Key('navigation-platform'),
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Журнал',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
