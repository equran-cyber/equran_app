import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/duas/duas_page.dart';
import 'package:equran/home/downloads.dart';
import 'package:equran/home/main_page.dart';
import 'package:equran/home/player.dart';
import 'package:equran/home/settings.dart';
import 'package:equran/prayer/prayer_times_page.dart';
import 'package:equran/prayer/qibla_page.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:flutter/material.dart';

const EdgeInsets _drawerTilePadding = EdgeInsets.symmetric(horizontal: 12);
const int _downloadsDestinationIndex = 3;
const int _settingsDestinationIndex = 5;
const List<int> _drawerDestinationIndices = <int>[0, 1, 2, 4];

class Destinations {
  const Destinations(
    this.label,
    this.icon,
    this.selectedIcon,
    this.destination,
  );

  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final Widget destination;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _previousPageIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Destinations> _pageDestinations = <Destinations>[
    Destinations(
      'Home',
      Icon(Icons.home_outlined),
      Icon(Icons.home_rounded),
      MainPage(),
    ),
    Destinations(
      'Player',
      Icon(Icons.library_music_outlined),
      Icon(Icons.library_music),
      PlayerPage(),
    ),
    Destinations(
      'Duas',
      Icon(Icons.auto_stories_outlined),
      Icon(Icons.auto_stories_rounded),
      DuasPage(),
    ),
    Destinations(
      'Downloads',
      Icon(Icons.download_outlined),
      Icon(Icons.download_rounded),
      DownloadsPage(),
    ),
    Destinations(
      'Prayer Times',
      Icon(Icons.access_time_outlined),
      Icon(Icons.schedule_rounded),
      PrayerTimesPage(),
    ),
    Destinations(
      'Settings',
      Icon(Icons.settings_outlined),
      Icon(Icons.settings),
      SettingsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool tabletLayout = ResponsiveNav.isTablet(context);
    final double navIconSize = ResponsiveNav.iconSize(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool showSecondaryBackButton = _isSecondaryPage(_selectedIndex);

    return Scaffold(
      key: _scaffoldKey,
      drawer: showSecondaryBackButton
          ? null
          : NavigationDrawerTheme(
              data: NavigationDrawerTheme.of(context).copyWith(
                labelTextStyle: WidgetStatePropertyAll(
                  ResponsiveNav.drawerLabelStyle(context),
                ),
                tileHeight: ResponsiveNav.drawerTileHeight(context),
                indicatorColor: colorScheme.secondaryContainer.withValues(
                  alpha: 0.45,
                ),
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: NavigationDrawer(
                onDestinationSelected: (index) {
                  _onDrawerDestinationSelected(index);
                },
                selectedIndex: _selectedDrawerIndex,
                tilePadding: _drawerTilePadding,
                children: <Widget>[
                  SizedBox(height: tabletLayout ? 76 : 64),
                  ..._drawerDestinationIndices.map((int destinationIndex) {
                    final Destinations destination =
                        _pageDestinations[destinationIndex];
                    return NavigationDrawerDestination(
                      label: Text(destination.label),
                      icon: IconTheme(
                        data: IconThemeData(
                          color: colorScheme.onSurfaceVariant,
                          size: navIconSize,
                        ),
                        child: destination.icon,
                      ),
                      selectedIcon: IconTheme(
                        data: IconThemeData(
                          color: colorScheme.onSecondaryContainer,
                          size: navIconSize,
                        ),
                        child: destination.selectedIcon,
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Divider(indent: 18, endIndent: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Settings',
                          iconSize: navIconSize,
                          color: _selectedIndex == _settingsDestinationIndex
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          onPressed: _openSettingsFromDrawer,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                        IconButton(
                          tooltip: 'Downloads',
                          iconSize: navIconSize,
                          color: _selectedIndex == _downloadsDestinationIndex
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          onPressed: _openDownloadsFromDrawer,
                          icon: const Icon(Icons.download_outlined),
                        ),
                        IconButton(
                          tooltip: 'Toggle theme',
                          iconSize: navIconSize,
                          color: colorScheme.onSurfaceVariant,
                          onPressed: _toggleQuickTheme,
                          icon: Icon(
                            theme.brightness == Brightness.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      appBar: _selectedIndex >= 2
          ? AppBar(
              toolbarHeight: ResponsiveNav.toolbarHeight(context),
              leading: showSecondaryBackButton
                  ? IconButton(
                      tooltip: 'Back',
                      onPressed: _returnToPreviousPage,
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  : null,
              title: Text(_pageDestinations[_selectedIndex].label),
              centerTitle: true,
              iconTheme: IconThemeData(
                color: colorScheme.onSurface,
                size: navIconSize,
              ),
              actions: <Widget>[
                if (_pageDestinations[_selectedIndex].destination
                    is PrayerTimesPage)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: IconButton(
                      tooltip: 'Qibla',
                      onPressed: _openQiblaPage,
                      icon: const Icon(Icons.explore_outlined),
                    ),
                  ),
              ],
            )
          : null,
      body: _pageDestinations[_selectedIndex].destination,
    );
  }

  int? get _selectedDrawerIndex {
    final int drawerIndex = _drawerDestinationIndices.indexOf(_selectedIndex);
    return drawerIndex < 0 ? null : drawerIndex;
  }

  void _onDrawerDestinationSelected(int index) {
    final int destinationIndex = _drawerDestinationIndices[index];
    _onItemTapped(destinationIndex);
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _openSettingsFromDrawer() {
    _scaffoldKey.currentState?.closeDrawer();
    _pushDrawerPage(_settingsDestinationIndex);
  }

  void _openDownloadsFromDrawer() {
    _scaffoldKey.currentState?.closeDrawer();
    _pushDrawerPage(_downloadsDestinationIndex);
  }

  void _pushDrawerPage(int index) {
    final Destinations destination = _pageDestinations[index];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: ResponsiveNav.toolbarHeight(context),
              title: Text(destination.label),
              centerTitle: true,
              iconTheme: IconThemeData(
                size: ResponsiveNav.iconSize(context),
              ),
            ),
            body: destination.destination,
          );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      if (_isSecondaryPage(index) && !_isSecondaryPage(_selectedIndex)) {
        _previousPageIndex = _selectedIndex;
      }
      _selectedIndex = index;
    });
  }

  bool _isSecondaryPage(int index) {
    return index == _downloadsDestinationIndex ||
        index == _settingsDestinationIndex;
  }

  void _returnToPreviousPage() {
    setState(() {
      _selectedIndex = _isSecondaryPage(_previousPageIndex)
          ? 0
          : _previousPageIndex;
    });
  }

  void _openQiblaPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const QiblaPage(),
      ),
    );
  }

  Future<void> _toggleQuickTheme() async {
    final ThemeData theme = Theme.of(context);
    final AdaptiveThemeMode mode = AdaptiveTheme.of(context).mode;
    final bool isDark = mode.isSystem
        ? theme.brightness == Brightness.dark
        : mode.isDark;
    final AdaptiveThemeMode nextMode = isDark
        ? AdaptiveThemeMode.light
        : AdaptiveThemeMode.dark;

    await SettingsDB().put('themeMode', nextMode.isDark ? 'dark' : 'light');
    if (!mounted) return;
    AdaptiveTheme.of(context).setThemeMode(nextMode);
  }
}
