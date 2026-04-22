import 'package:equran/backend/favourites_db.dart';
import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';

const int _favouriteNoteMaxLength = 80;

class ReadQuranCard extends StatelessWidget {
  final int currentChapter;
  final int currentVerse;
  final int totalVerses;
  final int juzNumber;

  final String translation;
  final String transliteration;
  final String verse;
  final String? basmala;

  final double fontSize;
  final double fontSizeTranslation;
  final bool showActions;
  final bool showTransliteration;

  final VoidCallback? onPlay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onDownload;
  final VoidCallback? onTafsir;
  final bool isPlaying;
  final bool isDownloading;
  final bool isDownloaded;

  const ReadQuranCard({
    super.key,
    required this.currentChapter,
    required this.currentVerse,
    required this.totalVerses,
    required this.fontSize,
    required this.fontSizeTranslation,
    required this.juzNumber,
    required this.translation,
    this.transliteration = '',
    this.basmala,
    required this.verse,
    this.showActions = true,
    this.showTransliteration = false,
    this.onPlay,
    this.onPrevious,
    this.onNext,
    this.onDownload,
    this.onTafsir,
    this.isPlaying = false,
    this.isDownloading = false,
    this.isDownloaded = false,
  });

  String get _favouriteKey {
    return '$currentChapter-${currentVerse.toString().padLeft(3, '0')}';
  }

  Future<void> _showInputPrompt(BuildContext context) async {
    final TextEditingController textController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Favourite ayah'),
            content: TextField(
              maxLength: _favouriteNoteMaxLength,
              maxLines: null,
              controller: textController,
              decoration: const InputDecoration(hintText: 'Optional note...'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  FavouritesDB().put(_favouriteKey, textController.text.trim());
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Save'),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final TextStyle? mutedStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorScheme.primary.withAlpha(36)),
                ),
                child: Text("Juz' $juzNumber", style: mutedStyle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ayah $currentVerse of $totalVerses',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mutedStyle?.copyWith(
                    color: colorScheme.onSurfaceVariant.withAlpha(190),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showActions) ...<Widget>[
          const SizedBox(width: 8),
          _buildHeaderActions(context),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required Widget child,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isPrimary
          ? colorScheme.primary.withAlpha(24)
          : colorScheme.surfaceContainerHighest.withAlpha(140),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(height: 42, width: 42, child: Center(child: child)),
        ),
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isFavourite = FavouritesDB().contains(_favouriteKey);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildActionButton(
          context: context,
          tooltip: isPlaying ? 'Pause' : 'Play',
          onPressed: onPlay,
          isPrimary: true,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 22,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _buildActionButton(
                context: context,
                tooltip: 'Previous ayah',
                onPressed: onPrevious,
                child: Icon(
                  Icons.skip_previous_rounded,
                  size: 24,
                  color: colorScheme.onSurface.withAlpha(185),
                ),
              ),
              _buildActionButton(
                context: context,
                tooltip: isPlaying ? 'Pause' : 'Play',
                onPressed: onPlay,
                isPrimary: true,
                child: Icon(
                  isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 28,
                  color: colorScheme.primary,
                ),
              ),
              _buildActionButton(
                context: context,
                tooltip: isDownloaded
                    ? 'Current ayah downloaded'
                    : isDownloading
                    ? 'Downloading'
                    : 'Download current ayah',
                onPressed: isDownloading ? null : onDownload,
                child: isDownloading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: colorScheme.onSurface.withAlpha(185),
                        ),
                      )
                    : Icon(
                        isDownloaded
                            ? Icons.offline_pin_rounded
                            : Icons.download_rounded,
                        size: 22,
                        color: colorScheme.onSurface.withAlpha(185),
                      ),
              ),
              _buildActionButton(
                context: context,
                tooltip: 'Next ayah',
                onPressed: onNext,
                child: Icon(
                  Icons.skip_next_rounded,
                  size: 24,
                  color: colorScheme.onSurface.withAlpha(185),
                ),
              ),
              _buildActionButton(
                context: context,
                tooltip: isFavourite ? 'Remove favourite' : 'Favourite',
                onPressed: null,
                child: LikeButton(
                  size: 22,
                  isLiked: isFavourite,
                  onTap: (bool liked) async {
                    if (!liked) {
                      await _showInputPrompt(context);
                    } else {
                      FavouritesDB().delete(_favouriteKey);
                    }
                    return !liked;
                  },
                ),
        ),
        const SizedBox(width: 6),
        _buildActionButton(
          context: context,
          tooltip: 'Tafsir',
          onPressed: onTafsir,
          child: Icon(
            Icons.chrome_reader_mode_rounded,
            size: 19,
            color: colorScheme.onSurface.withAlpha(185),
          ),
        ),
        const SizedBox(width: 6),
        _buildActionButton(
          context: context,
          tooltip: isFavourite ? 'Remove favourite' : 'Favourite',
          onPressed: null,
          child: LikeButton(
            size: 19,
            isLiked: isFavourite,
            onTap: (bool liked) async {
              if (!liked) {
                await _showInputPrompt(context);
              } else {
                FavouritesDB().delete(_favouriteKey);
              }
              return !liked;
            },
          ),
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

    final Color resolvedCardColor =
        theme.cardTheme.color ??
        (isLight
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainer);

    double marginValue;
    if (screenSize.width > 1200) {
      marginValue = 120.0;
    } else if (screenSize.width > 700) {
      marginValue = 40.0;
    } else {
      marginValue = 6.0;
    }

    return Card(
      elevation: isLight ? 3 : 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(horizontal: marginValue, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: isLight
              ? colorScheme.primary.withAlpha(28)
              : colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          color: resolvedCardColor,
          gradient: isLight
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color.alphaBlend(
                      colorScheme.primary.withAlpha(10),
                      resolvedCardColor,
                    ),
                    Color.alphaBlend(
                      colorScheme.tertiary.withAlpha(8),
                      resolvedCardColor,
                    ),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color.alphaBlend(
                      colorScheme.primary.withAlpha(14),
                      resolvedCardColor,
                    ),
                    Color.alphaBlend(
                      colorScheme.secondary.withAlpha(8),
                      resolvedCardColor,
                    ),
                  ],
                ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(isLight ? 10 : 20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(context),
              const SizedBox(height: 16),
              if (basmala != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    basmala!,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Hafs',
                      fontSize: fontSize,
                      height: 1.7,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              Text(
                verse,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Hafs',
                  height: 1.85,
                  fontSize: fontSize,
                  color: colorScheme.onSurface,
                ),
              ),
              if (showTransliteration && transliteration.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    transliteration,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: (fontSizeTranslation - 1)
                          .clamp(12.0, 20.0)
                          .toDouble(),
                      color: colorScheme.onSurfaceVariant.withAlpha(220),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              if (SettingsDB().get("enableTranslation", defaultValue: true))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    translation,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: fontSizeTranslation,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
