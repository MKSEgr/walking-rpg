import 'package:flutter/material.dart';

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
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[widget.home, widget.platform],
      ),
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
