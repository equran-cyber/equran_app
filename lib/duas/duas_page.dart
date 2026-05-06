import 'dart:math' as math;

import 'package:equran/duas/hisn_al_muslim_models.dart';
import 'package:equran/duas/hisn_al_muslim_repository.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';

class DuasPage extends StatefulWidget {
  const DuasPage({
    super.key,
    this.repository = const HisnAlMuslimRepository(),
  });

  final HisnAlMuslimRepository repository;

  @override
  State<DuasPage> createState() => _DuasPageState();
}

class _DuasPageState extends State<DuasPage> {
  late final Future<List<HisnCategory>> _categoriesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.repository.loadCategories();
    _searchController.addListener(_handleSearchChanged);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HisnCategory>>(
      future: _categoriesFuture,
      builder: (BuildContext context, AsyncSnapshot<List<HisnCategory>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DuasLoadingState();
        }

        if (snapshot.hasError) {
          return _DuasMessageState(
            icon: Icons.error_outline_rounded,
            title: 'Duas unavailable',
            message:
                'Hisn al Muslim could not be loaded from the offline asset.',
          );
        }

        final List<HisnCategory> categories = snapshot.data ?? const <HisnCategory>[];
        if (categories.isEmpty) {
          return const _DuasMessageState(
            icon: Icons.menu_book_outlined,
            title: 'No duas found',
            message: 'The offline Hisn al Muslim file did not contain any duas.',
          );
        }

        return _DuasContent(
          categories: categories,
          query: _query,
          searchController: _searchController,
        );
      },
    );
  }
}

class _DuasContent extends StatelessWidget {
  const _DuasContent({
    required this.categories,
    required this.query,
    required this.searchController,
  });

  final List<HisnCategory> categories;
  final String query;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<HisnCategory> visibleCategories = _visibleCategories();
    final int duaCount = categories.fold<int>(
      0,
      (int total, HisnCategory category) => total + category.duas.length,
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
                  categoryCount: categories.length,
                  duaCount: duaCount,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    hintText: 'Search categories or duas',
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
                if (visibleCategories.isEmpty)
                  const _DuasMessageState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching duas',
                    message: 'Try searching with another Arabic word or phrase.',
                  )
                else
                  ...visibleCategories.map((HisnCategory category) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _DuaCategorySection(
                        category: category,
                        initiallyExpanded:
                            query.isNotEmpty || category.duas.length <= 3,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<HisnCategory> _visibleCategories() {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return categories;
    return categories
        .where((HisnCategory category) => category.matches(normalizedQuery))
        .map((HisnCategory category) => category.filtered(normalizedQuery))
        .where((HisnCategory category) => category.duas.isNotEmpty)
        .toList(growable: false);
  }
}

class _DuasHero extends StatelessWidget {
  const _DuasHero({
    required this.categoryCount,
    required this.duaCount,
  });

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
                    '$categoryCount Arabic categories • $duaCount duas offline',
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

class _DuaCategorySection extends StatelessWidget {
  const _DuaCategorySection({
    required this.category,
    required this.initiallyExpanded,
  });

  final HisnCategory category;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                category.title,
                textAlign: TextAlign.right,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.45,
                  color: colors.onSurface,
                ),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${category.duas.length} ${category.duas.length == 1 ? "dua" : "duas"}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            children: <Widget>[
              for (int index = 0; index < category.duas.length; index++)
                _DuaCard(
                  dua: category.duas[index],
                  number: index + 1,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  const _DuaCard({
    required this.dua,
    required this.number,
  });

  final HisnDua dua;
  final int number;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<String> metadata = <String>[
      if (dua.count != null && dua.count! > 1) 'Repeat ${dua.count}x',
      if (dua.reference != null) dua.reference!,
      if (dua.source != null) dua.source!,
      if (dua.notes != null) dua.notes!,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.78),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _DuaNumberBadge(number: number),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        dua.text,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: 'Hafs',
                          height: 1.95,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (dua.transliteration != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  dua.transliteration!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (dua.translation != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  dua.translation!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
              if (metadata.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: metadata.map((String item) {
                    return _DuaMetadataPill(text: item);
                  }).toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DuaNumberBadge extends StatelessWidget {
  const _DuaNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int cappedNumber = math.max(1, number);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Text(
            '$cappedNumber',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DuaMetadataPill extends StatelessWidget {
  const _DuaMetadataPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          text,
          textDirection: _looksArabic(text) ? TextDirection.rtl : TextDirection.ltr,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  bool _looksArabic(String value) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(value);
  }
}

class _DuasLoadingState extends StatelessWidget {
  const _DuasLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _DuasMessageState extends StatelessWidget {
  const _DuasMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
