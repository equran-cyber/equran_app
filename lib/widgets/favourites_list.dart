import 'package:equran/backend/library.dart';
import 'package:equran/home/library.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

class FavouritesList extends StatefulWidget {
  const FavouritesList({super.key});

  @override
  State<FavouritesList> createState() => _FavouritesListState();
}

class _FavouritesListState extends State<FavouritesList> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<_SavedAyah> items = _savedAyahs();

    if (items.isEmpty) {
      return const Center(child: Text('No saved ayahs yet.'));
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final _SavedAyah ayah = items[index];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ReadPage(
                  chapter: ayah.surah,
                  startVerse: ayah.verse,
                ),
              ),
            ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showBottomSheetWithOptions(
                  context,
                  ayah.key,
                  _controller,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<_SavedAyah> _savedAyahs() {
    final keys = FavouritesDB().getKeys().toList();
    final List<_SavedAyah> parsed = <_SavedAyah>[];
    for (final dynamic raw in keys) {
      final key = raw.toString();
      final parts = key.split('-');
      if (parts.length != 2) continue;
      final int? surah = int.tryParse(parts[0]);
      final int? verse = int.tryParse(parts[1]);
      if (surah == null || verse == null) continue;
      parsed.add(
        _SavedAyah(
          key: key,
          surah: surah,
          verse: verse,
          note: FavouritesDB().get(key, defaultValue: ''),
        ),
      );
    }
    parsed.sort((a, b) {
      if (a.surah != b.surah) return a.surah.compareTo(b.surah);
      return a.verse.compareTo(b.verse);
    });
    return parsed;
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
}

void _showBottomSheetWithOptions(
    BuildContext context, String key, TextEditingController controller) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Wrap(
        children: <Widget>[
          InkWell(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            onTap: () {
              _showEditNoteDialog(
                context,
                key,
                FavouritesDB().get(key, defaultValue: ""),
                controller,
              );
            },
            child: const ListTile(
              leading: Icon(Icons.edit_rounded),
              title: Text('Edit'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_rounded),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              FavouritesDB().delete(key);
            },
          ),
        ],
      );
    },
  );
}

void _showEditNoteDialog(BuildContext context, String key, String initialNote,
    TextEditingController controller) {
  controller.text = initialNote;
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
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
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
