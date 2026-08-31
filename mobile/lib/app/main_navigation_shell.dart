import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_chrome_insets.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_destination_visibility.dart';
import 'package:walking_rpg_mobile/design_system/expedition_navigation_glyph.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

const double _wideNavigationBreakpoint = 960;
const double _wideNavigationMinimumSafeHeight = 480;

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    required this.home,
    required this.platform,
    this.crew,
    this.onDestinationChanged,
  });

  final Widget home;
  final Widget platform;
  final Widget? crew;
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
        final double safeHeight =
            constraints.maxHeight - MediaQuery.paddingOf(context).vertical;
        final bool wide =
            constraints.maxWidth >= _wideNavigationBreakpoint &&
            safeHeight >= _wideNavigationMinimumSafeHeight;
        return Scaffold(
          key: const Key('main-navigation-shell'),
          extendBody: !wide,
          body: Row(
            children: <Widget>[
              if (wide) _buildWideNavigation(context),
              if (wide) const SizedBox(width: 12),
              Expanded(
                key: const Key('main-navigation-destinations'),
                child: NavigationChromeInsets(
                  bottomDockInset: wide
                      ? 0
                      : NavigationChromeInsets.compactBottomDockInset,
                  child: _buildDestinations(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : _buildCompactNavigation(constraints.maxWidth),
        );
      },
    );
  }

  Widget _buildDestinations() {
    return IndexedStack(
      key: const Key('main-navigation-stack'),
      index: _selectedIndex,
      children: <Widget>[
        NavigationDestinationVisibility(
          isVisible: _selectedIndex == 0,
          child: widget.home,
        ),
        if (widget.crew case final Widget crew)
          NavigationDestinationVisibility(
            isVisible: _selectedIndex == 1,
            child: crew,
          ),
        NavigationDestinationVisibility(
          isVisible: _selectedIndex == _platformIndex,
          child: widget.platform,
        ),
      ],
    );
  }

  Widget _buildCompactNavigation(double availableWidth) {
    final double horizontalInset = availableWidth < 360 ? 8 : 16;
    return SafeArea(
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
            destinations: <NavigationDestination>[
              NavigationDestination(
                key: const Key('navigation-home'),
                icon: const ExpeditionNavigationGlyph(
                  destination: ExpeditionNavigationDestination.expedition,
                  selected: false,
                ),
                selectedIcon: const ExpeditionNavigationGlyph(
                  destination: ExpeditionNavigationDestination.expedition,
                  selected: true,
                ),
                label: context.l10n.navigationExpeditionLabel,
              ),
              if (widget.crew != null)
                NavigationDestination(
                  key: const Key('navigation-crew'),
                  icon: const ExpeditionNavigationGlyph(
                    destination: ExpeditionNavigationDestination.crew,
                    selected: false,
                  ),
                  selectedIcon: const ExpeditionNavigationGlyph(
                    destination: ExpeditionNavigationDestination.crew,
                    selected: true,
                  ),
                  label: context.l10n.navigationCrewLabel,
                ),
              NavigationDestination(
                key: const Key('navigation-platform'),
                icon: const ExpeditionNavigationGlyph(
                  destination: ExpeditionNavigationDestination.journal,
                  selected: false,
                ),
                selectedIcon: const ExpeditionNavigationGlyph(
                  destination: ExpeditionNavigationDestination.journal,
                  selected: true,
                ),
                label: context.l10n.navigationJournalLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideNavigation(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return SafeArea(
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
                selectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                  child: ExpeditionBadge(
                    label: context.l10n.navigationFieldTerminal,
                    icon: Icons.route_outlined,
                    allowWrap: true,
                  ),
                ),
                destinations: <NavigationRailDestination>[
                  NavigationRailDestination(
                    icon: ExpeditionNavigationGlyph(
                      key: const Key('navigation-home-wide'),
                      destination: ExpeditionNavigationDestination.expedition,
                      selected: _selectedIndex == 0,
                    ),
                    label: Text(context.l10n.navigationExpeditionLabel),
                  ),
                  if (widget.crew != null)
                    NavigationRailDestination(
                      icon: ExpeditionNavigationGlyph(
                        key: const Key('navigation-crew-wide'),
                        destination: ExpeditionNavigationDestination.crew,
                        selected: _selectedIndex == 1,
                      ),
                      label: Text(context.l10n.navigationCrewLabel),
                    ),
                  NavigationRailDestination(
                    icon: ExpeditionNavigationGlyph(
                      key: const Key('navigation-platform-wide'),
                      destination: ExpeditionNavigationDestination.journal,
                      selected: _selectedIndex == _platformIndex,
                    ),
                    label: Text(context.l10n.navigationJournalLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
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

  int get _platformIndex => widget.crew == null ? 1 : 2;
}
