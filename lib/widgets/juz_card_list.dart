import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

import 'juz_card.dart';

class JuzCardList extends StatefulWidget {
  const JuzCardList({
    super.key,
    required this.searchQuery,
  });

  final String searchQuery;

  @override
  _JuzCardListState createState() => _JuzCardListState();
}

class _JuzCardListState extends State<JuzCardList>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _fallbackScrollController = ScrollController();
  final Map<int, GlobalKey> _sectionKeys = <int, GlobalKey>{};

  @override
  void dispose() {
    _fallbackScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ScrollController scrollController =
        PrimaryScrollController.maybeOf(context) ?? _fallbackScrollController;
    final List<_JuzGroup> juzGroups = _buildJuzGroups(widget.searchQuery);

    if (juzGroups.isEmpty) {
      return const Center(child: Text('No juz results found.'));
    }

    _syncSectionKeys(juzGroups);

    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 24),
          child: Column(
            children: juzGroups.map((group) {
              final List<QuranJuzTile> juzCards = group.entries
                  .map(
                    (_JuzEntry entry) => QuranJuzTile(
                      id: entry.surahId,
                      transliteration: entry.transliteration,
                      name: entry.name,
                      startVerse: entry.startVerse,
                      endVerse: entry.endVerse,
                    ),
                  )
                  .toList();

              return KeyedSubtree(
                key: _sectionKeys[group.juzNumber],
                child: _JuzGroupSection(
                  juzNumber: group.juzNumber,
                  surahCount: group.entries.length,
                  children: juzCards,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _syncSectionKeys(List<_JuzGroup> groups) {
    final Set<int> groupNumbers =
        groups.map((group) => group.juzNumber).toSet();
    _sectionKeys.removeWhere((int juzNumber, GlobalKey _) {
      return !groupNumbers.contains(juzNumber);
    });

    for (final _JuzGroup group in groups) {
      _sectionKeys.putIfAbsent(group.juzNumber, GlobalKey.new);
    }
  }

  List<_JuzGroup> _buildJuzGroups(String searchQuery) {
    final String query = searchQuery.trim().toLowerCase();
    final List<_JuzGroup> groups = <_JuzGroup>[];

    for (int juzNumber = 1; juzNumber <= 30; juzNumber++) {
      final Map<int, List<int>> juz = quran.getSurahAndVersesFromJuz(juzNumber);
      final List<_JuzEntry> entries = <_JuzEntry>[];

      juz.forEach((surahId, verses) {
        final _JuzEntry entry = _JuzEntry(
          surahId: surahId,
          transliteration: quran.getSurahName(surahId),
          name: quran.getSurahNameArabic(surahId),
          startVerse: verses[0],
          endVerse: verses[1],
        );

        if (query.isEmpty || entry.matches(query, juzNumber)) {
          entries.add(entry);
        }
      });

      if (entries.isNotEmpty) {
        groups.add(_JuzGroup(juzNumber: juzNumber, entries: entries));
      }
    }

    return groups;
  }

  @override
  bool get wantKeepAlive => true;
}

class _JuzSectionHeader extends StatelessWidget {
  const _JuzSectionHeader({
    required this.juzNumber,
    required this.surahCount,
  });

  final int juzNumber;
  final int surahCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                colorScheme.primaryContainer.withOpacity(0.9),
                colorScheme.tertiaryContainer.withOpacity(0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.12),
            ),
          ),
          child: Text(
            "Juz' $juzNumber",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onPrimaryContainer,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.45),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$surahCount surahs',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _JuzGroupSection extends StatelessWidget {
  const _JuzGroupSection({
    required this.juzNumber,
    required this.surahCount,
    required this.children,
  });

  final int juzNumber;
  final int surahCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: _JuzSectionHeader(
              juzNumber: juzNumber,
              surahCount: surahCount,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _JuzGroup {
  const _JuzGroup({
    required this.juzNumber,
    required this.entries,
  });

  final int juzNumber;
  final List<_JuzEntry> entries;
}

class _JuzEntry {
  const _JuzEntry({
    required this.surahId,
    required this.transliteration,
    required this.name,
    required this.startVerse,
    required this.endVerse,
  });

  final int surahId;
  final String transliteration;
  final String name;
  final int startVerse;
  final int endVerse;

  bool matches(String query, int juzNumber) {
    return juzNumber.toString() == query;
  }
}
