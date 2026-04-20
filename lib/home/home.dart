import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/home/downloads.dart';
import 'package:equran/home/main_page.dart';
import 'package:equran/home/player.dart';
import 'package:equran/home/settings.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _appDownloadUrl =
    'https://f-droid.org/en/packages/com.app.equran/';
const String _issueReportUrl = 'https://github.com/ya27hw/equran_app/issues';
const String _contactEmail = 'equran@elbaesy.com';
const EdgeInsets _drawerTilePadding = EdgeInsets.symmetric(horizontal: 12);
const double _drawerTileLeadingGap = 16;
const double _drawerTileIconLabelGap = 12;

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
  final List<Destinations> _pageDestinations = <Destinations>[
    const Destinations(
      "eQuran",
      Icon(Icons.book_outlined),
      Icon(Icons.book),
      MainPage(),
    ),
    const Destinations(
      "Player",
      Icon(Icons.library_music_outlined),
      Icon(Icons.library_music),
      PlayerPage(),
    ),
    const Destinations(
      "Downloads",
      Icon(Icons.download_done_outlined),
      Icon(Icons.download_done_rounded),
      DownloadsPage(),
    ),
    const Destinations(
      "Settings",
      Icon(Icons.settings_outlined),
      Icon(Icons.settings),
      SettingsPage(),
    ),
  ];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool tabletLayout = ResponsiveNav.isTablet(context);
    final double navIconSize = ResponsiveNav.iconSize(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      drawer: NavigationDrawerTheme(
        data: NavigationDrawerTheme.of(context).copyWith(
          labelTextStyle: WidgetStatePropertyAll(
            ResponsiveNav.drawerLabelStyle(context),
          ),
          tileHeight: ResponsiveNav.drawerTileHeight(context),
        ),
        child: NavigationDrawer(
          onDestinationSelected: (index) {
            _scaffoldKey.currentState!.closeDrawer();
            _onItemTapped(index);
          },
          selectedIndex: _selectedIndex,
          tilePadding: _drawerTilePadding,
          footer: _buildDrawerFooter(context),
          children: <Widget>[
            SizedBox(height: tabletLayout ? 84 : 72),
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
          ],
        ),
      ),
      appBar: _selectedIndex >= 2
          ? AppBar(
              toolbarHeight: ResponsiveNav.toolbarHeight(context),
              title: Text(_pageDestinations[_selectedIndex].label),
              iconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface,
                size: navIconSize,
              ),
              centerTitle: true,
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

  Widget _buildThemeToggleFooterButton(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AdaptiveThemeMode themeMode = AdaptiveTheme.of(context).mode;
    final bool isDark = themeMode.isSystem
        ? theme.brightness == Brightness.dark
        : themeMode.isDark;

    return _buildDrawerFooterButton(
      context: context,
      icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      label: isDark ? 'Light mode' : 'Dark mode',
      onPressed: () async {
        final AdaptiveThemeMode newMode = isDark
            ? AdaptiveThemeMode.light
            : AdaptiveThemeMode.dark;
        await SettingsDB().put('themeMode', newMode.isDark ? 'dark' : 'light');
        if (context.mounted) {
          AdaptiveTheme.of(context).setThemeMode(newMode);
        }
      },
    );
  }

  Widget _buildDrawerFooter(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildThemeToggleFooterButton(context),
            const SizedBox(height: 2),
            _buildDrawerFooterButton(
              context: context,
              icon: Icons.info_outline,
              label: 'About this app',
              onPressed: () => _showAboutApp(context),
            ),
            const SizedBox(height: 2),
            _buildDrawerFooterButton(
              context: context,
              icon: Icons.share_outlined,
              label: 'Share this app',
              onPressed: () => _shareApp(context),
            ),
            const SizedBox(height: 2),
            _buildDrawerFooterButton(
              context: context,
              icon: Icons.feedback_outlined,
              label: 'Feedback / Contact us',
              onPressed: () => _openFeedbackContactPage(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerFooterButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? labelStyle =
        NavigationDrawerTheme.of(
          context,
        ).labelTextStyle?.resolve(<WidgetState>{}) ??
        theme.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );

    return Padding(
      padding: _drawerTilePadding,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: double.infinity,
            height: ResponsiveNav.drawerFooterTileHeight(context),
            child: Row(
              children: <Widget>[
                const SizedBox(width: _drawerTileLeadingGap),
                SizedBox(
                  width: ResponsiveNav.iconSize(context),
                  child: Icon(
                    icon,
                    color: colorScheme.onSurfaceVariant,
                    size: ResponsiveNav.iconSize(context),
                  ),
                ),
                const SizedBox(width: _drawerTileIconLabelGap),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAboutApp(BuildContext context) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    showAboutDialog(
      context: context,
      applicationName: 'eQuran',
      applicationVersion: 'Version ${packageInfo.version}',
      applicationIcon: Icon(
        Icons.menu_book_rounded,
        color: colorScheme.primary,
        size: 40,
      ),
      children: const <Widget>[
        SizedBox(height: 16),
        Text(
          'eQuran is a modern Quran companion designed for focused reading, listening, and daily reflection.',
        ),
        SizedBox(height: 12),
        Text(
          'Use it to continue where you left off, browse by Surah or Juz, stream recitation, play specific ayahs, and download audio for offline listening.',
        ),
        SizedBox(height: 12),
        Text(
          'Built with a clean Material 3 interface, eQuran keeps the experience simple, elegant, and reliable.',
        ),
      ],
    );
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'eQuran',
          subject: 'Download eQuran',
          text: 'Download eQuran on F-Droid: $_appDownloadUrl',
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the share sheet.')),
      );
    }
  }

  void _openFeedbackContactPage(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => const FeedbackContactPage(),
      ),
    );
  }
}

class FeedbackContactPage extends StatelessWidget {
  const FeedbackContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ResponsiveNav.toolbarHeight(context),
        iconTheme: IconThemeData(size: ResponsiveNav.iconSize(context)),
        title: const Text('Feedback / Contact us'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'Help improve eQuran',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'We appreciate your suggestions and feedback; they help make eQuran better for everyone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report issues'),
            subtitle: const Text('Open the GitHub issue tracker.'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => _launchUri(
              context,
              Uri.parse(_issueReportUrl),
              errorMessage: 'Unable to open the issue tracker.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.alternate_email_rounded),
            title: const Text('Contact'),
            subtitle: const Text(_contactEmail),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => _launchUri(
              context,
              Uri(
                scheme: 'mailto',
                path: _contactEmail,
                queryParameters: <String, String>{'subject': 'eQuran feedback'},
              ),
              errorMessage: 'Unable to open your email app.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUri(
    BuildContext context,
    Uri uri, {
    required String errorMessage,
  }) async {
    final bool didLaunch;
    try {
      didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    if (didLaunch || !context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage)));
  }
}
