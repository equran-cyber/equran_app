import 'dart:math';

import 'package:equran/backend/library.dart';
import 'package:equran/home/read.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:quran/quran.dart';

class LastReadCard extends StatelessWidget {
  const LastReadCard({super.key});

  List<ReadingEntry> displayReadingHistory() {
    final entries = BookmarkDB()
        .box
        .toMap()
        .values
        .whereType<ReadingEntry>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.take(7).toList();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double viewportFraction = 1;
    const double threshold = 450.0;

    if (width > threshold) {
      double scaledWidth = (width - threshold) / 900;
      viewportFraction = 1.0 * exp(-scaledWidth);
    } else {
      viewportFraction = 1;
    }

    List<ReadingEntry> entries = displayReadingHistory();
    return ExpandableCarousel.builder(
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int itemIndex, int pageViewIndex) {
        ReadingEntry entry = entries[itemIndex];
        int keySurah = entry.surah;
        int verse = entry.verse;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 2,
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ReadPage(
                      chapter: keySurah,
                      startVerse: verse,
                    ))),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Theme.of(context).colorScheme.primaryContainer.withOpacity(0.72),
                    Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.52),
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Last Read',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      getSurahName(keySurah),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ayah $verse',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      options: ExpandableCarouselOptions(
          showIndicator: true,
          viewportFraction: viewportFraction,
          initialPage: 0),
    );
  }
}
