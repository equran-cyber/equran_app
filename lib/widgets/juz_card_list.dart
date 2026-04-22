import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

import 'juz_card.dart';

class JuzCardList extends StatefulWidget {
  const JuzCardList({super.key, required this.searchQuery});

  final String searchQuery;

  @override
  State<JuzCardList> createState() => _JuzCardListState();
}

class _JuzCardListState extends State<JuzCardList>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _fallbackScrollController = ScrollController();

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

    final List<_JuzListItem> items = _buildListItems(juzGroups);
    final double textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.2).toDouble();
    final double headerExtent = 58 * textScale;
    final double tileExtent = 132 * textScale;

    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      interactive: true,
      child: ListView.builder(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 8, bottom: 24),
        itemCount: items.length,
        itemExtentBuilder: (int index, _) {
          return items[index].group != null ? headerExtent : tileExtent;
        },
        cacheExtent: tileExtent * 8,
        itemBuilder: (BuildContext context, int index) {
          final _JuzListItem item = items[index];
          final _JuzGroup? group = item.group;
          if (group != null) {
            return SizedBox(
              key: ValueKey<String>('juz-header-${group.juzNumber}'),
              height: headerExtent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                child: _JuzSectionHeader(
                  juzNumber: group.juzNumber,
                  surahCount: group.entries.length,
                ),
              ),
            );
          }

          final _JuzEntry entry = item.entry!;
          return SizedBox(
            key: ValueKey<String>(
              'juz-${entry.surahId}-${entry.startVerse}-${entry.endVerse}',
            ),
            height: tileExtent,
            child: QuranJuzTile(
              id: entry.surahId,
              transliteration: entry.transliteration,
              name: entry.name,
              startVerse: entry.startVerse,
              endVerse: entry.endVerse,
            ),
          );
        },
      ),
    );
  }

  List<_JuzListItem> _buildListItems(List<_JuzGroup> groups) {
    final List<_JuzListItem> items = <_JuzListItem>[];
    for (final _JuzGroup group in groups) {
      items.add(_JuzListItem.group(group));
      for (final _JuzEntry entry in group.entries) {
        items.add(_JuzListItem.entry(entry));
      }
    }
    return items;
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
  const _JuzSectionHeader({required this.juzNumber, required this.surahCount});

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
                colorScheme.primaryContainer.withValues(alpha: 0.9),
                colorScheme.tertiaryContainer.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.12),
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
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
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

class _JuzGroup {
  const _JuzGroup({required this.juzNumber, required this.entries});

  final int juzNumber;
  final List<_JuzEntry> entries;
}

class _JuzListItem {
  const _JuzListItem.group(this.group) : entry = null;

  const _JuzListItem.entry(this.entry) : group = null;

  final _JuzGroup? group;
  final _JuzEntry? entry;
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
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return juzNumber.toString() == normalized ||
        juzNumber.toString().startsWith(normalized) ||
        transliteration.toLowerCase().contains(normalized) ||
        name.contains(query);
  }
}
