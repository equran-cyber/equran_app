import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/backend/library.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/debouncer.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:equran/widgets/library.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  final Debouncer _debouncer = Debouncer(milliseconds: 400);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _surahScrollController = ScrollController();
  final ScrollController _juzScrollController = ScrollController();
  final ScrollController _favouritesScrollController = ScrollController();
  late final TabController _tabController;

  String _searchQuery = '';
  int _selectedSegment = 0;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _debouncer.cancel();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _surahScrollController.dispose();
    _juzScrollController.dispose();
    _favouritesScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final double horizontalPadding = width >= 1400
        ? 36
        : width >= 1100
        ? 28
        : 14;
    return Column(
      children: <Widget>[
        DecoratedBox(
          decoration: _topBarDecoration(theme),
          child: SafeArea(
            bottom: false,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: _buildTopBar(theme),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            10,
            horizontalPadding,
            15,
          ),
          child: _buildSectionHeader(theme),
        ),
        Expanded(child: _buildSegmentPager(horizontalPadding)),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Row(
      children: <Widget>[
        Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            style: ResponsiveNav.iconButtonStyle(context),
            icon: Icon(
              Icons.menu_rounded,
              size: ResponsiveNav.iconSize(context),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _showSearch
                ? SearchBar(
                    key: const ValueKey<String>('header-search'),
                    controller: _searchController,
                    leading: const Icon(Icons.search_rounded),
                    trailing: <Widget>[
                      IconButton(
                        tooltip: 'Close search',
                        onPressed: _closeSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                    hintText: _searchHint,
                    hintStyle: WidgetStatePropertyAll(
                      theme.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onChanged: _changeSearchQuery,
                    elevation: const WidgetStatePropertyAll(0),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey<String>('header-title'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _scrollToTop,
                    child: Text(
                      'eQuran',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Row(
            key: ValueKey<bool>(_showSearch),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!_showSearch)
                IconButton(
                  tooltip: 'Toggle theme',
                  onPressed: _toggleQuickTheme,
                  icon: Icon(
                    theme.brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
              _showSearch
                  ? const SizedBox(
                      key: ValueKey<String>('search-button-hidden'),
                      width: 0,
                    )
                  : IconButton(
                      key: const ValueKey<String>('search-button'),
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _topBarDecoration(ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return BoxDecoration(
      color: isLight ? null : colorScheme.primaryContainer,
      gradient: isLight
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.alphaBlend(
                  colorScheme.primary.withAlpha(28),
                  colorScheme.surfaceContainerLow,
                ),
                Color.alphaBlend(
                  colorScheme.tertiary.withAlpha(18),
                  colorScheme.surfaceContainerLow,
                ),
              ],
            )
          : null,
      border: Border(
        bottom: BorderSide(
          color: isLight
              ? colorScheme.primary.withAlpha(34)
              : colorScheme.outlineVariant.withAlpha(120),
        ),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: colorScheme.shadow.withAlpha(isLight ? 20 : 14),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isLight
                ? colorScheme.surfaceContainerLow
                : colorScheme.surfaceContainerHighest.withAlpha(150),
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colorScheme.shadow.withAlpha(18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    colorScheme.primaryContainer,
                    colorScheme.tertiaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadii.small),
                border: Border.all(color: colorScheme.primary.withAlpha(58)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colorScheme.shadow.withAlpha(18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              labelColor: colorScheme.onPrimaryContainer,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overlayColor: WidgetStatePropertyAll(
                colorScheme.primary.withAlpha(16),
              ),
              splashBorderRadius: BorderRadius.circular(AppRadii.small),
              tabs: <Widget>[
                _buildTabLabel(Icons.menu_book_outlined, 'Surah'),
                _buildTabLabel(Icons.layers_outlined, 'Juz'),
                _buildTabLabel(Icons.favorite_border_rounded, 'Saved'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabLabel(IconData icon, String label) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 19),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildSegmentPager(double horizontalPadding) {
    return TabBarView(
      controller: _tabController,
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: PrimaryScrollController(
            controller: _surahScrollController,
            child: QuranCardList(
              key: const ValueKey<String>('surah-list'),
              searchQuery: _searchQuery,
              header: _buildLastReadCard(),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: PrimaryScrollController(
            controller: _juzScrollController,
            child: JuzCardList(
              key: ValueKey<String>('juz-list'),
              searchQuery: _searchQuery,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ValueListenableBuilder(
            key: const ValueKey<String>('page-list'),
            valueListenable: FavouritesDB().listener,
            builder: (BuildContext context, Box<dynamic> box, child) {
              if (box.length == 0) {
                return const SizedBox.shrink();
              } else {
                return PrimaryScrollController(
                  controller: _favouritesScrollController,
                  child: FavouritesList(searchQuery: _searchQuery),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  void _changeSearchQuery(String value) {
    _debouncer.call(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
      });
    });
  }

  void _openSearch() {
    setState(() {
      _showSearch = true;
    });
  }

  void _closeSearch() {
    _debouncer.cancel();
    setState(() {
      _showSearch = false;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _handleTabChanged() {
    if (_selectedSegment == _tabController.index) return;
    setState(() {
      _selectedSegment = _tabController.index;
    });
  }

  String get _searchHint => switch (_selectedSegment) {
    1 => "Juz number or surah name...",
    2 => "Saved ayah, surah, note, or number...",
    _ => "Surah name or number...",
  };

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

  Widget? _buildLastReadCard() {
    if (SettingsDB().get("showLastRead", defaultValue: true) != true) {
      return null;
    }

    return ValueListenableBuilder(
      valueListenable: BookmarkDB().listener,
      builder: (BuildContext context, Box<dynamic> box, child) {
        final entries = box.values.whereType<ReadingEntry>().toList();
        Widget currentChild = const SizedBox.shrink(
          key: ValueKey<String>('last-read-empty'),
        );

        if (entries.isNotEmpty) {
          currentChild = LastReadCard(
            key: const ValueKey<String>('last-read-card'),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
            );
          },
          child: currentChild,
        );
      },
    );
  }

  void _scrollToTop() {
    final ScrollController scrollController = switch (_selectedSegment) {
      0 => _surahScrollController,
      1 => _juzScrollController,
      _ => _favouritesScrollController,
    };
    if (!scrollController.hasClients) return;

    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}
