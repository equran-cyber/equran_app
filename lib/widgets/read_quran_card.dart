import 'package:equran/backend/favourites_db.dart';
import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/utils/app_radii.dart';
import 'package:equran/widgets/library.dart';
import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';

const int _favouriteNoteMaxLength = 80;

class ReadQuranCard extends StatelessWidget {
  final int currentChapter;
  final int currentVerse;
  final int totalVerses;
  final int juzNumber;

  final String translation;
  final String verse;
  final Future<String> url;
  final String? basmala;

  final double fontSize;
  final double fontSizeTranslation;
  final Future<void> Function(int surah, int ayah)? onPlayRequested;
  final bool showActions;

  const ReadQuranCard({
    super.key,
    required this.currentChapter,
    required this.currentVerse,
    required this.totalVerses,
    required this.fontSize,
    required this.fontSizeTranslation,
    required this.juzNumber,
    required this.translation,
    this.basmala,
    required this.verse,
    required this.url,
    this.onPlayRequested,
    this.showActions = true,
  });

  String get _favouriteKey {
    return "$currentChapter-${currentVerse.toString().padLeft(3, "0")}";
  }

  Future<void> _showInputPrompt(BuildContext context) async {
    final TextEditingController textController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Enter a note:'),
            content: TextField(
              maxLength: _favouriteNoteMaxLength,
              maxLines: null,
              controller: textController,
              decoration: const InputDecoration(hintText: "Optional..."),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  FavouritesDB().put(_favouriteKey, textController.text);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } finally {
      textController.dispose();
    }
  }

  Widget _buildHeader(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.bodyLarge;
    final String label = "Juz' $juzNumber - $currentVerse/$totalVerses";

    if (!showActions) {
      return Text(
        label,
        style: labelStyle?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        PlayButton(
          key: ValueKey('$currentChapter-$currentVerse'),
          url: url,
          surah: currentChapter,
          ayah: currentVerse,
          onPlayRequested: onPlayRequested,
        ),
        Text(label, style: labelStyle),
        LikeButton(
          isLiked: FavouritesDB().contains(_favouriteKey),
          onTap: (bool isLiked) async {
            if (!isLiked) {
              await _showInputPrompt(context);
            } else {
              FavouritesDB().delete(_favouriteKey);
            }
            return !isLiked;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    double marginValue;
    if (screenSize.width > 1200) {
      marginValue = 120.0;
    } else if (screenSize.width > 700) {
      marginValue = 40.0;
    } else {
      marginValue = 8.0;
    }

    return Card(
      elevation: isLight ? 5 : 4,
      color: isLight ? Colors.transparent : null,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(horizontal: marginValue, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: isLight
              ? colorScheme.primary.withAlpha(38)
              : colorScheme.outlineVariant.withAlpha(90),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isLight
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color.alphaBlend(
                      colorScheme.primary.withAlpha(12),
                      colorScheme.surfaceContainerLow,
                    ),
                    Color.alphaBlend(
                      colorScheme.tertiary.withAlpha(10),
                      colorScheme.surfaceContainerLowest,
                    ),
                  ],
                )
              : null,
          color: isLight ? null : colorScheme.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: <Widget>[
              _buildHeader(context),
              if (basmala != null)
                Text(
                  basmala!,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 2,
                    fontFamily: 'Hafs',
                    fontSize: fontSize,
                  ),
                ),
              Text(
                verse,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontFamily: 'Hafs',
                  height: 1.65,
                  fontSize: fontSize,
                ),
              ),
              if (SettingsDB().get("enableTranslation", defaultValue: true))
                Text(
                  translation,
                  textAlign: TextAlign.justify,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: fontSizeTranslation,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
