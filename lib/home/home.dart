import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/home/downloads.dart';
import 'package:equran/home/main_page.dart';
import 'package:equran/home/player.dart';
import 'package:equran/home/settings.dart';
import 'package:equran/prayer/prayer_times_page.dart';
import 'package:equran/prayer/qibla_page.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:flutter/material.dart';

const EdgeInsets _drawerTilePadding = EdgeInsets.symmetric(horizontal: 12);

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Destinations> _pageDestinations = const <Destinations>[
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
      'Downloads',
      Icon(Icons.download_done_outlined),
      Icon(Icons.download_done_rounded),
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

    return Scaffold(
      key: _scaffoldKey,
      drawer: NavigationDrawerTheme(
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
            _scaffoldKey.currentState!.closeDrawer();
            _onItemTapped(index);
          },
          selectedIndex: _selectedIndex,
          tilePadding: _drawerTilePadding,
          children: <Widget>[
            SizedBox(height: tabletLayout ? 76 : 64),
            ..._pageDestinations.map((Destinations destination) {
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
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                leading: Icon(
                  theme.brightness == Brightness.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  size: navIconSize,
                ),
                title: const Text('Theme'),
                trailing: Switch.adaptive(
                  value: theme.brightness == Brightness.dark,
                  onChanged: (_) => _toggleQuickTheme(),
                ),
                onTap: _toggleQuickTheme,
              ),
            ),
          ],
        ),
      ),
      appBar: _selectedIndex >= 2
          ? AppBar(
              toolbarHeight: ResponsiveNav.toolbarHeight(context),
              title: Text(_pageDestinations[_selectedIndex].label),
              centerTitle: true,
              iconTheme: IconThemeData(
                color: colorScheme.onSurface,
                size: navIconSize,
              ),
              actions: <Widget>[
                if (_pageDestinations[_selectedIndex].destination
                    is PrayerTimesPage)
                  IconButton(
                    tooltip: 'Qibla',
                    onPressed: _openQiblaPage,
                    icon: const Icon(Icons.explore_outlined),
                  ),
              ],
            )
          : null,
      body: _pageDestinations[_selectedIndex].destination,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
