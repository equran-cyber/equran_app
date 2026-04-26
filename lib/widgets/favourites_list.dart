import 'package:equran/backend/library.dart';
import 'package:equran/home/library.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/saved_ayah.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:quran/quran.dart' as quran;

const int _favouriteNoteMaxLength = 90;

class FavouritesList extends StatefulWidget {
  const FavouritesList({super.key, required this.searchQuery});

  final String searchQuery;

  @override
  State<FavouritesList> createState() => _FavouritesListState();
}

class _FavouritesListState extends State<FavouritesList> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _fallbackScrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _fallbackScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController =
        PrimaryScrollController.maybeOf(context) ?? _fallbackScrollController;

    return ValueListenableBuilder(
      valueListenable: FavouritesDB().listener,
      builder: (BuildContext context, Box<dynamic> box, child) {
        final List<SavedAyah> items = _savedAyahs(widget.searchQuery);
        final List<_FavouriteSurahGroup> groups = _groupBySurah(items);

        if (items.isEmpty) {
          return _buildEmptyState(context);
        }

        return Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.builder(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final _FavouriteSurahGroup group = groups[index];
              return _FavouriteSurahSection(
                key: ValueKey<int>(group.surah),
                group: group,
                controller: _controller,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isSearching = widget.searchQuery.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.favorite_border_rounded,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? 'No saved ayah results found.'
                  : 'No saved ayahs yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!isSearching) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'In page view, long-press an ayah and choose Favourite. In card view, tap the like button on the ayah card.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<SavedAyah> _savedAyahs(String searchQuery) {
    return savedAyahsFromKeys(
      keys: FavouritesDB().getKeys(),
      noteForKey: (key) => FavouritesDB().get(key, defaultValue: ''),
      searchQuery: searchQuery,
    );
  }

  List<_FavouriteSurahGroup> _groupBySurah(List<SavedAyah> ayahs) {
    final Map<int, List<SavedAyah>> bySurah = <int, List<SavedAyah>>{};

    for (final SavedAyah ayah in ayahs) {
      bySurah.putIfAbsent(ayah.surah, () => <SavedAyah>[]).add(ayah);
    }

    return bySurah.entries.map((entry) {
      return _FavouriteSurahGroup(surah: entry.key, ayahs: entry.value);
    }).toList();
  }
}

class _FavouriteSurahGroup {
  const _FavouriteSurahGroup({required this.surah, required this.ayahs});

  final int surah;
  final List<SavedAyah> ayahs;
}

class _FavouriteSurahSection extends StatelessWidget {
  const _FavouriteSurahSection({
    super.key,
    required this.group,
    required this.controller,
  });

  final _FavouriteSurahGroup group;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(150)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group.surah.toString().padLeft(2, '0'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          quran.getSurahName(group.surah),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${group.ayahs.length} favourited ${group.ayahs.length == 1 ? 'ayah' : 'ayahs'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (int index = 0; index < group.ayahs.length; index++) ...[
                _SavedAyahTile(
                  key: ValueKey<String>(group.ayahs[index].key),
                  ayah: group.ayahs[index],
                  controller: controller,
                  isLast: index == group.ayahs.length - 1,
                ),
                if (index != group.ayahs.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAyahTile extends StatefulWidget {
  const _SavedAyahTile({
    super.key,
    required this.ayah,
    required this.controller,
    required this.isLast,
  });

  final SavedAyah ayah;
  final TextEditingController controller;
  final bool isLast;

  @override
  State<_SavedAyahTile> createState() => _SavedAyahTileState();
}

class _SavedAyahTileState extends State<_SavedAyahTile> {
  static const double _revealWidth = 112;

  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final SavedAyah ayah = widget.ayah;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Stack(
        alignment: Alignment.centerRight,
        children: <Widget>[
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _revealWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    IconButton.filledTonal(
                      tooltip: 'Edit',
                      onPressed: () {
                        _close();
                        _showEditNoteDialog(
                          context,
                          ayah.key,
                          FavouritesDB().get(ayah.key, defaultValue: ""),
                          widget.controller,
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Delete',
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                      ),
                      onPressed: () => FavouritesDB().delete(ayah.key),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset = (_dragOffset - details.delta.dx)
                    .clamp(0.0, _revealWidth)
                    .toDouble();
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() {
                _dragOffset = _dragOffset >= _revealWidth / 2
                    ? _revealWidth
                    : 0;
              });
            },
            child: SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(-_dragOffset, 0, 0),
                child: Material(
                  color: colorScheme.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withAlpha(95),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    onTap: () {
                      if (_dragOffset > 0) {
                        _close();
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ReadPage(
                            chapter: ayah.surah,
                            startVerse: ayah.verse,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: IntrinsicHeight(
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Column(
                            children: <Widget>[
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withAlpha(
                                    175,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  ayah.verse.toString(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (ayah.note.isNotEmpty)
                                Expanded(
                                  child: Container(
                                  width: 1,
                                  
                                  margin: const EdgeInsets.only(top: 4),
                                  color: colorScheme.outlineVariant,
                                ),
                                )
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Ayah ${ayah.verse}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (ayah.note.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    ayah.note,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.25,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    quran.getSurahNameArabic(ayah.surah),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      )
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _close() {
    setState(() {
      _dragOffset = 0;
    });
  }
}

void _showEditNoteDialog(
  BuildContext context,
  String key,
  String initialNote,
  TextEditingController controller,
) {
  controller.text = initialNote;
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
          maxLength: _favouriteNoteMaxLength,
          maxLines: null,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              FavouritesDB().put(key, controller.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
