import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_destination_visibility.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

const double _wideNavigationBreakpoint = 960;

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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget destinations = _buildDestinations();
        if (constraints.maxWidth >= _wideNavigationBreakpoint) {
          return _buildWideShell(context, destinations);
        }
        return _buildCompactShell(constraints.maxWidth, destinations);
      },
    );
  }

  Widget _buildDestinations() {
    return IndexedStack(
      index: _selectedIndex,
      children: <Widget>[
        NavigationDestinationVisibility(
          isVisible: _selectedIndex == 0,
          child: widget.home,
        ),
        NavigationDestinationVisibility(
          isVisible: _selectedIndex == 1,
          child: widget.platform,
        ),
      ],
    );
  }

  Widget _buildCompactShell(double availableWidth, Widget destinations) {
    final double horizontalInset = availableWidth < 360 ? 8 : 16;
    return Scaffold(
      key: const Key('main-navigation-compact'),
      extendBody: true,
      body: destinations,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 12),
        child: DecoratedBox(
          key: const Key('main-navigation-bottom-dock'),
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
              onDestinationSelected: _selectDestination,
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

  Widget _buildWideShell(BuildContext context, Widget destinations) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Scaffold(
      key: const Key('main-navigation-wide'),
      body: Row(
        children: <Widget>[
          SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
              child: SizedBox(
                width: 224,
                height: double.infinity,
                child: ExpeditionPanel(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: NavigationRail(
                      key: const Key('main-navigation-rail'),
                      extended: true,
                      minWidth: 72,
                      minExtendedWidth: 224,
                      groupAlignment: -0.58,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      backgroundColor: Colors.transparent,
                      indicatorColor: colors.primaryContainer,
                      selectedIconTheme: IconThemeData(color: colors.primary),
                      unselectedIconTheme: IconThemeData(
                        color: colors.onSurfaceVariant,
                      ),
                      selectedLabelTextStyle: theme.textTheme.labelLarge
                          ?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                      unselectedLabelTextStyle: theme.textTheme.labelLarge
                          ?.copyWith(color: colors.onSurfaceVariant),
                      leading: const Padding(
                        padding: EdgeInsets.fromLTRB(14, 16, 14, 24),
                        child: ExpeditionBadge(
                          label: 'Полевой терминал',
                          icon: Icons.route_outlined,
                          allowWrap: true,
                        ),
                      ),
                      destinations: <NavigationRailDestination>[
                        NavigationRailDestination(
                          icon: Icon(
                            _selectedIndex == 0
                                ? Icons.explore
                                : Icons.explore_outlined,
                            key: const Key('navigation-home-wide'),
                          ),
                          label: const Text('Экспедиция'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            _selectedIndex == 1
                                ? Icons.menu_book
                                : Icons.menu_book_outlined,
                            key: const Key('navigation-platform-wide'),
                          ),
                          label: const Text('Журнал'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: destinations),
        ],
      ),
    );
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    widget.onDestinationChanged?.call(index);
  }
}
