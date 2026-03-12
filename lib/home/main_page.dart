import 'dart:async';

import 'package:equran/backend/library.dart';
import 'package:equran/utils/debouncer.dart';
import 'package:equran/widgets/library.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final Debouncer _debouncer = Debouncer(milliseconds: 400);
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<BoxEvent>? _bookmarkSubscription;
  StreamSubscription<BoxEvent>? _favouritesSubscription;

  String _searchQuery = '';
  int _selectedSegment = 0;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _bookmarkSubscription = BookmarkDB().box.watch().listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    _favouritesSubscription = FavouritesDB().box.watch().listen((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _bookmarkSubscription?.cancel();
    _favouritesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Builder(
                  builder: (context) => IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded),
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
                            hintText: 'Search surah name or number...',
                            onChanged: _changeSearchQuery,
                            elevation: const WidgetStatePropertyAll(0),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                        : Text(
                            'eQuran',
                            key: const ValueKey<String>('header-title'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchController.clear();
                        _changeSearchQuery('');
                      }
                    });
                  },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _showSearch ? Icons.close_rounded : Icons.search_rounded,
                      key: ValueKey<bool>(_showSearch),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (SettingsDB().get("showLastRead", defaultValue: true) == true)
              ValueListenableBuilder(
                valueListenable: BookmarkDB().listener,
                builder: (BuildContext context, Box<dynamic> box, child) {
                  final entries = box.values.whereType<ReadingEntry>().toList();
                  if (entries.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                  final latest = entries.first;

                  return LastReadCard(
                    key: ValueKey<String>(
                      '${latest.surah}-${latest.verse}-${latest.timestamp.microsecondsSinceEpoch}',
                    ),
                  );
                },
              ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Text(
                  'Al Quran',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 0, label: Text('Surah')),
                    ButtonSegment<int>(value: 1, label: Text('Juz')),
                    ButtonSegment<int>(
                      value: 2,
                      icon: Icon(Icons.favorite_rounded),
                    ),
                  ],
                  selected: <int>{_selectedSegment},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedSegment = selection.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildSegmentBody(colorScheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentBody(ColorScheme colorScheme) {
    if (_selectedSegment == 0) {
      return QuranCardList(
        key: const ValueKey<String>('surah-list'),
        searchQuery: _searchQuery,
      );
    }

    if (_selectedSegment == 1) {
      return const JuzCardList(
        key: ValueKey<String>('juz-list'),
      );
    }

    return ValueListenableBuilder(
      key: const ValueKey<String>('page-list'),
      valueListenable: FavouritesDB().listener,
      builder: (BuildContext context, Box<dynamic> box, child) {
        if (box.length == 0) {
          return const SizedBox.shrink();
        } else {
          return const FavouritesList();
        }
      },
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
}
