import 'package:equran/backend/dua_favourites_db.dart';
import 'package:equran/duas/duas_category_page.dart';
import 'package:equran/duas/duas_favourites_page.dart';
import 'package:equran/duas/hisn_al_muslim_models.dart';
import 'package:equran/duas/hisn_al_muslim_repository.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive/hive.dart';

class DuasPage extends StatefulWidget {
  DuasPage({super.key, HisnAlMuslimRepository? repository})
    : repository = repository ?? HisnAlMuslimRepository();

  final HisnAlMuslimRepository repository;

  @override
  State<DuasPage> createState() => _DuasPageState();
}

class _DuasPageState extends State<DuasPage> {
  Future<List<DuaCategoryIndex>>? _categoryIndexFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCategoryIndex();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final String nextQuery = _searchController.text.trim();
    if (nextQuery == _query) return;
    setState(() {
      _query = nextQuery;
    });
  }

  void _loadCategoryIndex() {
    setState(() {
      _categoryIndexFuture = _loadCategoryIndexAfterLoadingFrame();
    });
  }

  Future<List<DuaCategoryIndex>> _loadCategoryIndexAfterLoadingFrame() async {
    await SchedulerBinding.instance.endOfFrame;
    return widget.repository.loadCategoryIndex();
  }

  @override
  Widget build(BuildContext context) {
    final Future<List<DuaCategoryIndex>>? categoryIndexFuture =
        _categoryIndexFuture;
    if (categoryIndexFuture == null) {
      return const _DuasLoadingState();
    }

    return FutureBuilder<List<DuaCategoryIndex>>(
      future: categoryIndexFuture,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<DuaCategoryIndex>> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _DuasLoadingState();
            }

            if (snapshot.hasError) {
              return _DuasMessageState(
                icon: Icons.error_outline_rounded,
                title: 'Duas unavailable',
                message:
                    'Hisn al Muslim could not be loaded from the offline asset.',
                actionLabel: 'Retry',
                onActionPressed: _loadCategoryIndex,
              );
            }

            final List<DuaCategoryIndex> categoryIndex =
                snapshot.data ?? const <DuaCategoryIndex>[];
            if (categoryIndex.isEmpty) {
              return const _DuasMessageState(
                icon: Icons.menu_book_outlined,
                title: 'No duas found',
                message:
                    'The offline Hisn al Muslim file did not contain any duas.',
              );
            }

            return _DuasContent(
              categoryIndex: categoryIndex,
              query: _query,
              searchController: _searchController,
              repository: widget.repository,
            );
          },
    );
  }
}

class _DuasContent extends StatelessWidget {
  const _DuasContent({
    required this.categoryIndex,
    required this.query,
    required this.searchController,
    required this.repository,
  });

  final List<DuaCategoryIndex> categoryIndex;
  final String query;
  final TextEditingController searchController;
  final HisnAlMuslimRepository repository;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<DuaCategoryIndex> visibleCategories = _visibleCategories();
    final int duaCount = categoryIndex.fold<int>(
      0,
      (int total, DuaCategoryIndex category) => total + category.duaCount,
    );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _DuasHero(
                  categoryCount: categoryIndex.length,
                  duaCount: duaCount,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<Box<dynamic>>(
                  valueListenable: DuaFavouritesDB().listener,
                  builder:
                      (BuildContext context, Box<dynamic> box, Widget? child) {
                        return _FavouritesEntryCard(
                          count: box.length,
                          onTap: () => _openFavourites(context),
                        );
                      },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    hintText: 'Search categories',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: searchController.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Categories',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (visibleCategories.isEmpty)
                  const _DuasMessageState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching categories',
                    message:
                        'Try searching with another Arabic word or phrase.',
                  )
                else
                  for (final DuaCategoryIndex category in visibleCategories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DuaCategoryCard(
                        category: category,
                        onTap: () => _openCategory(context, category),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<DuaCategoryIndex> _visibleCategories() {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return categoryIndex;
    return categoryIndex
        .where((DuaCategoryIndex category) => category.matches(normalizedQuery))
        .toList(growable: false);
  }

  void _openCategory(BuildContext context, DuaCategoryIndex category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return DuasCategoryPage(
            categoryIndex: category,
            repository: repository,
          );
        },
      ),
    );
  }

  void _openFavourites(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return DuasFavouritesPage(
            categoryIndex: categoryIndex,
            repository: repository,
          );
        },
      ),
    );
  }
}

class _DuasHero extends StatelessWidget {
  const _DuasHero({required this.categoryCount, required this.duaCount});

  final int categoryCount;
  final int duaCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.large),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              colors.primary.withAlpha(isLight ? 34 : 54),
              colors.surfaceContainerLow,
            ),
            Color.alphaBlend(
              colors.tertiary.withAlpha(isLight ? 24 : 42),
              colors.surfaceContainer,
            ),
            colors.surfaceContainerLow,
          ],
        ),
        border: Border.all(
          color: colors.primary.withValues(alpha: isLight ? 0.16 : 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Hisn al Muslim',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$categoryCount Arabic categories - $duaCount duas offline',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavouritesEntryCard extends StatelessWidget {
  const _FavouritesEntryCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return _TappablePanel(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withAlpha(190),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(
              count > 0
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Favourite duas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'Save duas here for quick access'
                      : '$count saved ${count == 1 ? 'dua' : 'duas'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _DuaCategoryCard extends StatelessWidget {
  const _DuaCategoryCard({required this.category, required this.onTap});

  final DuaCategoryIndex category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int visualIndex = category.index % _categoryIcons.length;

    return _TappablePanel(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                _categoryAccentColors[visualIndex].withAlpha(34),
                colors.surfaceContainerHighest,
              ),
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(
                color: _categoryAccentColors[visualIndex].withAlpha(70),
              ),
            ),
            child: Icon(
              _categoryIcons[visualIndex],
              color: _categoryAccentColors[visualIndex],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  category.title,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${category.duaCount} ${category.duaCount == 1 ? 'dua' : 'duas'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _TappablePanel extends StatelessWidget {
  const _TappablePanel({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final Color resolvedCardColor =
        theme.cardTheme.color ?? colors.surfaceContainerLow;

    return Card(
      elevation: isLight ? 2 : 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: isLight
              ? colors.primary.withAlpha(22)
              : colors.outlineVariant.withAlpha(82),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: resolvedCardColor,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.alphaBlend(
                  colors.primary.withAlpha(isLight ? 8 : 14),
                  resolvedCardColor,
                ),
                Color.alphaBlend(
                  colors.tertiary.withAlpha(isLight ? 6 : 10),
                  resolvedCardColor,
                ),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DuasLoadingState extends StatelessWidget {
  const _DuasLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 40,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}

class _DuasMessageState extends StatelessWidget {
  const _DuasMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, color: colors.primary, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  if (actionLabel != null && onActionPressed != null) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: onActionPressed,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const List<IconData> _categoryIcons = <IconData>[
  Icons.wb_sunny_outlined,
  Icons.nights_stay_outlined,
  Icons.home_outlined,
  Icons.local_florist_outlined,
  Icons.shield_outlined,
  Icons.volunteer_activism_outlined,
];

const List<Color> _categoryAccentColors = <Color>[
  Color(0xFF00A6A6),
  Color(0xFF7C6ADE),
  Color(0xFFD08700),
  Color(0xFF2E8B57),
  Color(0xFF4A8FE7),
  Color(0xFFC6538C),
];
