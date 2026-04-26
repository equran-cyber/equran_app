import 'dart:math';

import 'package:equran/backend/library.dart';
import 'package:equran/home/read.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:quran/quran.dart';

class LastReadCard extends StatefulWidget {
  const LastReadCard({super.key, required this.entries});

  final List<ReadingEntry> entries;

  static List<ReadingEntry> displayReadingHistory(Iterable<dynamic> values) {
    final rawEntries = values.whereType<ReadingEntry>().toList();

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

  Future<void> _handleMenuAction(String value, ReadingEntry entry) async {
    if (value == 'delete') {
      await BookmarkDB().delete(entry.surah);
    }
  }

  @override
  State<LastReadCard> createState() => _LastReadCardState();
}

class _LastReadCardState extends State<LastReadCard> {
  static const double _estimatedCarouselPageSize = 146;

  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant LastReadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.isEmpty) {
      _currentPage = 0;
      return;
    }

    final int maxPage = widget.entries.length - 1;
    if (_currentPage > maxPage) {
      _currentPage = maxPage;
    }
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

    final List<ReadingEntry> entries = widget.entries;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final int activeIndex = entries.isEmpty
        ? 0
        : _currentPage.clamp(0, entries.length - 1).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          children: <Widget>[
            ExpandableCarousel.builder(
              itemCount: entries.length,
              itemBuilder:
                  (BuildContext context, int itemIndex, int pageViewIndex) {
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
                        showIndicatorSpace: entries.length > 1,
                      ),
                    );
                  },
              options: ExpandableCarouselOptions(
                showIndicator: false,
                estimatedPageSize: _estimatedCarouselPageSize,
                enableInfiniteScroll: false,
                viewportFraction: viewportFraction,
                initialPage: 0,
                onPageChanged: (int index, _) {
                  if (!mounted) return;
                  final int normalizedIndex = index
                      .clamp(0, entries.length - 1)
                      .toInt();
                  setState(() {
                    _currentPage = normalizedIndex;
                  });
                },
              ),
            ),
            if (entries.length > 1)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CarouselPillsIndicator(
                        itemCount: entries.length,
                        activeIndex: activeIndex,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(itemCount, (index) {
        final bool isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 14 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withAlpha(88),
            borderRadius: BorderRadius.circular(999),
            boxShadow: isActive
                ? <BoxShadow>[
                    BoxShadow(
                      color: colorScheme.primary.withAlpha(34),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
    required this.showIndicatorSpace,
  });

  final ReadingEntry entry;
  final Future<void> Function(String value, ReadingEntry entry) onMenuAction;
  final bool showIndicatorSpace;

  @override
  Widget build(BuildContext context) {
    final int keySurah = entry.surah;
    final int verse = entry.verse;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 0,
                right: 67, // six sevennnnnn
                child: _BookmarkRibbon(
                  color: colorScheme.primary.withAlpha(isLight ? 58 : 74),
                  edgeColor: colorScheme.primary.withAlpha(isLight ? 70 : 92),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                        const SizedBox(width: 30),
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
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkRibbon extends StatelessWidget {
  const _BookmarkRibbon({required this.color, required this.edgeColor});

  final Color color;
  final Color edgeColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 58),
      painter: _BookmarkRibbonPainter(color: color, edgeColor: edgeColor),
    );
  }
}

class _BookmarkRibbonPainter extends CustomPainter {
  const _BookmarkRibbonPainter({required this.color, required this.edgeColor});

  final Color color;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Paint edge = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 9)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, edge);
  }

  @override
  bool shouldRepaint(covariant _BookmarkRibbonPainter oldDelegate) {
    return color != oldDelegate.color || edgeColor != oldDelegate.edgeColor;
  }
}
