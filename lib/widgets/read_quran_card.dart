import 'dart:async' show unawaited;

import 'package:equran/backend/favourites_db.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';

const int _favouriteNoteMaxLength = 80;

enum _CardOverflowAction { download, favourite, share }

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
  final bool showTranslation;
  final bool shareImageMode;

  final VoidCallback? onPlay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
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
    this.showTranslation = true,
    this.shareImageMode = false,
    this.onPlay,
    this.onPrevious,
    this.onNext,
    this.onDownload,
    this.onShare,
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

    final TextStyle? mutedStyle =
        (shareImageMode
                ? theme.textTheme.labelLarge
                : theme.textTheme.labelMedium)
            ?.copyWith(
              color: colorScheme.onSurfaceVariant.withAlpha(205),
              fontSize: shareImageMode ? 24 : null,
              fontWeight: FontWeight.w600,
            );

    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(14),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(color: colorScheme.primary.withAlpha(24)),
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
        if (showActions && !shareImageMode) ...<Widget>[
          const SizedBox(width: 10),
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
          ? colorScheme.primary.withAlpha(20)
          : colorScheme.surfaceContainerHighest.withAlpha(72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(height: 36, width: 36, child: Center(child: child)),
        ),
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isFavourite = FavouritesDB().contains(_favouriteKey);
    final double actionGap = MediaQuery.sizeOf(context).width >= 700 ? 8 : 4;

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
            size: 21,
            color: colorScheme.primary,
          ),
        ),

        if (onTafsir != null) ...<Widget>[
          SizedBox(width: actionGap),
          _buildActionButton(
            context: context,
            tooltip: 'Tafsir',
            onPressed: onTafsir,
            child: Icon(
              Icons.chrome_reader_mode_rounded,
              size: 18,
              color: colorScheme.onSurface.withAlpha(185),
            ),
          ),
        ],
        SizedBox(width: actionGap),
        _buildOverflowMenu(context: context, isFavourite: isFavourite),
      ],
    );
  }

  Widget _buildOverflowMenu({
    required BuildContext context,
    required bool isFavourite,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withAlpha(72),
      borderRadius: BorderRadius.circular(12),
      child: PopupMenuButton<_CardOverflowAction>(
        tooltip: 'More actions',
        position: PopupMenuPosition.under,
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: colorScheme.onSurface.withAlpha(185),
        ),
        style: IconButton.styleFrom(
          fixedSize: const Size(36, 36),
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onSelected: (action) {
          switch (action) {
            case _CardOverflowAction.download:
              onDownload?.call();
              break;
            case _CardOverflowAction.favourite:
              if (isFavourite) {
                FavouritesDB().delete(_favouriteKey);
              } else {
                unawaited(_showInputPrompt(context));
              }
              break;
            case _CardOverflowAction.share:
              onShare?.call();
              break;
          }
        },
        itemBuilder: (context) {
          return <PopupMenuEntry<_CardOverflowAction>>[
            PopupMenuItem<_CardOverflowAction>(
              value: _CardOverflowAction.download,
              enabled: !isDownloading && onDownload != null,
              child: _OverflowMenuItem(
                icon: isDownloading
                    ? Icons.downloading_rounded
                    : isDownloaded
                    ? Icons.offline_pin_rounded
                    : Icons.download_rounded,
                label: isDownloading
                    ? 'Downloading'
                    : isDownloaded
                    ? 'Downloaded'
                    : 'Download',
              ),
            ),
            PopupMenuItem<_CardOverflowAction>(
              value: _CardOverflowAction.favourite,
              child: _OverflowMenuItem(
                icon: isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: isFavourite ? 'Remove favourite' : 'Favourite',
              ),
            ),
            if (onShare != null)
              const PopupMenuItem<_CardOverflowAction>(
                value: _CardOverflowAction.share,
                child: _OverflowMenuItem(
                  icon: Icons.ios_share_rounded,
                  label: 'Share image',
                ),
              ),
          ];
        },
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
    final String trimmedTransliteration = transliteration.trim();
    final bool hasTransliteration =
        showTransliteration && trimmedTransliteration.isNotEmpty;
    final bool hasTranslation =
        showTranslation && translation.trim().isNotEmpty;
    final bool compactShareContent =
        shareImageMode && verse.runes.length <= 140;

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
          padding: EdgeInsets.fromLTRB(
            18,
            compactShareContent ? 14 : 16,
            18,
            shareImageMode ? (compactShareContent ? 14 : 16) : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(context),
              SizedBox(height: compactShareContent ? 14 : 18),
              if (basmala != null)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: compactShareContent ? 12 : 14,
                  ),
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
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontFamily: 'Hafs',
                  height: 1.78,
                  fontSize: fontSize,
                  color: colorScheme.onSurface,
                ),
              ),
              if (hasTransliteration)
                Padding(
                  padding: EdgeInsets.only(top: compactShareContent ? 12 : 14),
                  child: Text(
                    trimmedTransliteration,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: (fontSizeTranslation - 2)
                          .clamp(12.0, 18.0)
                          .toDouble(),
                      color: colorScheme.onSurfaceVariant.withAlpha(178),
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              if (hasTranslation) ...[
                Padding(
                  padding: EdgeInsets.only(
                    top: hasTransliteration
                        ? (compactShareContent ? 14 : 16)
                        : (compactShareContent ? 16 : 18),
                  ),
                  child: Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(118),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: compactShareContent ? 14 : 16),
                  child: Text(
                    translation,
                    textAlign: TextAlign.justify,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: fontSizeTranslation,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
              if (shareImageMode) ...<Widget>[
                SizedBox(height: compactShareContent ? 14 : 18),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withAlpha(90),
                ),
                SizedBox(height: compactShareContent ? 8 : 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'eQuran',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withAlpha(150),
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$currentChapter:$currentVerse',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withAlpha(140),
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OverflowMenuItem extends StatelessWidget {
  const _OverflowMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 19, color: colorScheme.onSurface.withAlpha(190)),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
