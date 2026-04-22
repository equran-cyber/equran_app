import 'dart:math';

import 'package:equran/backend/library.dart';
import 'package:equran/home/read.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:quran/quran.dart';

class LastReadCard extends StatefulWidget {
  const LastReadCard({super.key});

  Future<void> _handleMenuAction(String value, ReadingEntry entry) async {
    if (value == 'delete') {
      await BookmarkDB().delete(entry.surah);
    }
  }

  @override
  State<LastReadCard> createState() => _LastReadCardState();
}

class _LastReadCardState extends State<LastReadCard> {
  int _currentPage = 0;

  List<ReadingEntry> displayReadingHistory() {
    final rawEntries = BookmarkDB().box
        .toMap()
        .values
        .whereType<ReadingEntry>()
        .toList();

    // Keep one record per surah: latest ayah read only.
    final Map<int, ReadingEntry> latestPerSurah = <int, ReadingEntry>{};
    for (final entry in rawEntries) {
      final ReadingEntry? current = latestPerSurah[entry.surah];
      if (current == null || entry.timestamp.isAfter(current.timestamp)) {
        latestPerSurah[entry.surah] = entry;
      }
    }

    final entries = latestPerSurah.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.take(7).toList();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double viewportFraction = 1;
    const double threshold = 450.0;

    if (width > threshold) {
      double scaledWidth = (width - threshold) / 1100;
      viewportFraction = 1.0 * exp(-scaledWidth);
    } else {
      viewportFraction = 1;
    }

    List<ReadingEntry> entries = displayReadingHistory();
    final int activeIndex = entries.isEmpty
        ? 0
        : _currentPage.clamp(0, entries.length - 1).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExpandableCarousel.builder(
          itemCount: entries.length,
          itemBuilder: (BuildContext context, int itemIndex, int pageViewIndex) {
            final ReadingEntry entry = entries[itemIndex];
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final Animation<Offset> offsetAnimation = Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: _LastReadEntryCard(
                key: ValueKey<String>(
                  '${entry.surah}-${entry.verse}-${entry.timestamp.microsecondsSinceEpoch}',
                ),
                entry: entry,
                onMenuAction: widget._handleMenuAction,
              ),
            );
          },
          options: ExpandableCarouselOptions(
            showIndicator: false,
            viewportFraction: viewportFraction,
            initialPage: 0,
            onPageChanged: (int index, _) {
              if (!mounted) return;
              setState(() {
                _currentPage = index;
              });
            },
          ),
        ),
        if (entries.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          _CarouselPillsIndicator(
            itemCount: entries.length,
            activeIndex: activeIndex,
          ),
        ],
      ],
    );
  }
}

class _CarouselPillsIndicator extends StatelessWidget {
  const _CarouselPillsIndicator({
    required this.itemCount,
    required this.activeIndex,
  });

  final int itemCount;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(itemCount, (index) {
        final bool isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withAlpha(90),
            borderRadius: BorderRadius.circular(999),
            boxShadow: isActive
                ? <BoxShadow>[
                    BoxShadow(
                      color: colorScheme.primary.withAlpha(40),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _LastReadEntryCard extends StatelessWidget {
  const _LastReadEntryCard({
    super.key,
    required this.entry,
    required this.onMenuAction,
  });

  final ReadingEntry entry;
  final Future<void> Function(String value, ReadingEntry entry) onMenuAction;

  @override
  Widget build(BuildContext context) {
    final int keySurah = entry.surah;
    final int verse = entry.verse;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: isLight ? 4 : 2,
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: isLight
              ? colorScheme.primary.withAlpha(50)
              : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ReadPage(chapter: keySurah, startVerse: verse),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                isLight
                    ? Color.alphaBlend(
                        colorScheme.primary.withAlpha(28),
                        colorScheme.primaryContainer,
                      )
                    : colorScheme.primaryContainer,
                isLight
                    ? Color.alphaBlend(
                        colorScheme.tertiary.withAlpha(24),
                        colorScheme.tertiaryContainer,
                      )
                    : colorScheme.tertiaryContainer,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Last Read',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More options',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) => onMenuAction(value, entry),
                      itemBuilder: (BuildContext context) =>
                          const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline_rounded),
                                title: Text('Delete'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  getSurahName(keySurah),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ayah $verse',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
