import 'package:equran/backend/surah_model.dart';
import 'package:equran/home/read.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:equran/widgets/number_badge.dart';
import 'package:flutter/material.dart';

class QuranCard extends StatelessWidget {
  final Surah surah;
  final bool compact;

  const QuranCard({super.key, required this.surah, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool tabletLayout = ResponsiveNav.isTablet(context);
    final double verticalPadding = compact
        ? (tabletLayout ? 12 : 10)
        : (tabletLayout ? 14 : 12);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ReadPage(chapter: surah.id)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: verticalPadding,
          ),
          child: Row(
            children: <Widget>[
              NumberBadge(label: surah.id.toString(), size: compact ? 38 : 44),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      surah.transliteration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Text(
                          '${surah.verses} Ayahs',
                          style:
                              (compact
                                      ? theme.textTheme.bodyMedium
                                      : theme.textTheme.bodyLarge)
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
                style:
                    (compact
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.titleMedium)
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
