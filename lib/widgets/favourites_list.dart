import 'package:equran/backend/library.dart';
import 'package:equran/home/library.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:quran/quran.dart' as quran;

const int _favouriteNoteMaxLength = 80;

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
        final List<_SavedAyah> items = _savedAyahs(widget.searchQuery);

        if (items.isEmpty) {
          return _buildEmptyState(context);
        }

        return Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.separated(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final _SavedAyah ayah = items[index];
              return _SavedAyahTile(
                key: ValueKey<String>(ayah.key),
                ayah: ayah,
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

  List<_SavedAyah> _savedAyahs(String searchQuery) {
    final keys = FavouritesDB().getKeys().toList();
    final List<_SavedAyah> parsed = <_SavedAyah>[];
    final String query = searchQuery.trim().toLowerCase();
    for (final dynamic raw in keys) {
      final key = raw.toString();
      final parts = key.split('-');
      if (parts.length != 2) continue;
      final int? surah = int.tryParse(parts[0]);
      final int? verse = int.tryParse(parts[1]);
      if (surah == null || verse == null) continue;
      final _SavedAyah ayah = _SavedAyah(
        key: key,
        surah: surah,
        verse: verse,
        note: FavouritesDB().get(key, defaultValue: ''),
      );
      if (query.isEmpty || ayah.matches(query)) {
        parsed.add(ayah);
      }
    }
    parsed.sort((a, b) {
      if (a.surah != b.surah) return a.surah.compareTo(b.surah);
      return a.verse.compareTo(b.verse);
    });
    return parsed;
  }
}

class _SavedAyahTile extends StatefulWidget {
  const _SavedAyahTile({
    super.key,
    required this.ayah,
    required this.controller,
  });

  final _SavedAyah ayah;
  final TextEditingController controller;

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
    final _SavedAyah ayah = widget.ayah;

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
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
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
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ayah.surah.toString().padLeft(2, '0'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      title: Text(
                        quran.getSurahName(ayah.surah),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Ayah ${ayah.verse}'),
                          if (ayah.note.isNotEmpty)
                            Text(
                              ayah.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
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

class _SavedAyah {
  final String key;
  final int surah;
  final int verse;
  final String note;

  _SavedAyah({
    required this.key,
    required this.surah,
    required this.verse,
    required this.note,
  });

  bool matches(String query) {
    return quran.getSurahName(surah).toLowerCase().contains(query) ||
        quran.getSurahNameArabic(surah).toLowerCase().contains(query) ||
        note.toLowerCase().contains(query) ||
        surah.toString() == query ||
        verse.toString() == query ||
        'ayah $verse'.contains(query);
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
