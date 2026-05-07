import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/juz_search.dart';
import 'package:flutter/material.dart';

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
    final List<JuzGroup> juzGroups = buildJuzGroups(widget.searchQuery);

    if (juzGroups.isEmpty) {
      return const Center(child: Text('No juz results found.'));
    }

    final List<JuzListItem> items = buildJuzListItems(juzGroups);
    final double textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.2).toDouble();
    final double headerExtent = 74 * textScale;
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
          final JuzListItem item = items[index];
          final JuzGroup? group = item.group;
          if (group != null) {
            return SizedBox(
              key: ValueKey<String>('juz-header-${group.juzNumber}'),
              height: headerExtent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                child: _JuzSectionHeader(
                  juzNumber: group.juzNumber,
                  arabicName: group.arabicName,
                  surahCount: group.entries.length,
                ),
              ),
            );
          }

          final JuzEntry entry = item.entry!;
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

  @override
  bool get wantKeepAlive => true;
}

class _JuzSectionHeader extends StatelessWidget {
  const _JuzSectionHeader({
    required this.juzNumber,
    required this.arabicName,
    required this.surahCount,
  });

  final int juzNumber;
  final String arabicName;
  final int surahCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            "Juz' $juzNumber",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onPrimaryContainer,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                arabicName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'Hafs',
                  height: 1.28,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$surahCount surahs',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
