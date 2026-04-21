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
  final String verse;
  final String? basmala;

  final double fontSize;
  final double fontSizeTranslation;
  final bool showActions;

  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
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
    this.basmala,
    required this.verse,
    this.showActions = true,
    this.onPlay,
    this.onDownload,
    this.isPlaying = false,
    this.isDownloading = false,
    this.isDownloaded = false,
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
          final theme = Theme.of(context);

          return AlertDialog(
            title: const Text('Favourite ayah'),
            content: TextField(
              maxLength: _favouriteNoteMaxLength,
              maxLines: null,
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Optional note...',
              ),
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
                child: const Text(
                  'Save',
                ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final mutedStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.primary.withAlpha(36),
            ),
          ),
          child: Text(
            "Juz' $juzNumber",
            style: mutedStyle,
          ),
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
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required Widget child,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isPrimary
          ? colorScheme.primary.withAlpha(24)
          : colorScheme.surfaceContainerHighest.withAlpha(140),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            height: 48,
            width: 56,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    if (!showActions) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final bool isFavourite = FavouritesDB().contains(_favouriteKey);

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: <Widget>[
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withAlpha(90),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
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
                    ? 'All ayahs downloaded'
                    : isDownloading
                    ? 'Downloading'
                    : 'Download all ayahs',
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
            ],
          ),
        ],
      ),
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
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(context),
              const SizedBox(height: 18),
              if (basmala != null) ...[
                Text(
                  basmala!,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.9,
                    fontFamily: 'Hafs',
                    fontSize: fontSize,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                verse,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontFamily: 'Hafs',
                  height: 1.65,
                  fontSize: fontSize,
                  color: colorScheme.onSurface,
                ),
              ),
              if (SettingsDB().get(
                "enableTranslation",
                defaultValue: true,
              )) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(
                      isLight ? 115 : 90,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    translation,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: fontSizeTranslation,
                      height: 1.6,
                      color: colorScheme.onSurface.withAlpha(210),
                    ),
                  ),
                ),
              ],
              _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }
}