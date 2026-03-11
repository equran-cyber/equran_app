import 'package:equran/backend/surah_model.dart';
import 'package:equran/home/read.dart';
import 'package:flutter/material.dart';

class QuranCard extends StatelessWidget {
  final Surah surah;
  final bool compact;

  const QuranCard({super.key, required this.surah, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: compact ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReadPage(chapter: surah.id),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 10 : 12,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: compact ? 38 : 44,
                height: compact ? 38 : 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  surah.id.toString().padLeft(2, '0'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      surah.transliteration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Text(
                          '${surah.verses} Ayahs',
                          style: (compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
                              ?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                surah.name,
                style: (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
                    ?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
