import 'dart:async' show unawaited;

import 'package:equran/backend/favourites_db.dart';
import 'package:equran/backend/android_audio_display_mode.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/quran_text.dart';
import 'package:flutter/material.dart';

const int _favouriteNoteMaxLength = 80;

enum _CardOverflowAction {
  downloadOrDelete,
  favourite,
  share,
  switchTranslation,
}

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
  final VoidCallback? onDeleteDownload;
  final VoidCallback? onShare;
  final VoidCallback? onTafsir;
  final VoidCallback? onSwitchTranslation;
  final ValueChanged<bool>? onVisualOverlayChanged;
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
    this.onDeleteDownload,
    this.onShare,
    this.onTafsir,
    this.onSwitchTranslation,
    this.onVisualOverlayChanged,
    this.isPlaying = false,
    this.isDownloading = false,
    this.isDownloaded = false,
  });

  String get _favouriteKey {
    return favouriteAyahKey(currentChapter, currentVerse);
  }

  Future<void> _showInputPrompt(BuildContext context) async {
    final TextEditingController textController = TextEditingController();
    AndroidAudioDisplayMode.notifyUserActivity();
    onVisualOverlayChanged?.call(true);
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));
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
      onVisualOverlayChanged?.call(false);
      unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
      await WidgetsBinding.instance.endOfFrame;
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
    final String ayahLabel = shareImageMode
        ? 'Ayah $currentVerse'
        : 'Ayah $currentVerse of $totalVerses';

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
                  ayahLabel,
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
          const SizedBox(width: 12),
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
    final bool wideActions = MediaQuery.sizeOf(context).width >= 700;
    final double actionSize = wideActions ? 38 : 34;

    return Material(
      color: isPrimary ? colorScheme.primary.withAlpha(10) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            height: actionSize,
            width: actionSize,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: FavouritesDB().listener,
      builder: (context, favouritesBox, child) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final bool isFavourite = FavouritesDB().contains(_favouriteKey);
        final bool wideActions = MediaQuery.sizeOf(context).width >= 700;
        final double actionGap = wideActions ? 10 : 6;
        final double playIconSize = wideActions ? 23 : 21;
        final double actionIconSize = wideActions ? 20 : 18;

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
                size: playIconSize,
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
                  size: actionIconSize,
                  color: colorScheme.onSurface.withAlpha(168),
                ),
              ),
            ],
            SizedBox(width: actionGap),
            _buildOverflowMenu(
              context: context,
              isFavourite: isFavourite,
              showTranslation: showTranslation,
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverflowMenu({
    required BuildContext context,
    required bool isFavourite,
    required bool showTranslation,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool wideActions = MediaQuery.sizeOf(context).width >= 700;
    final double actionSize = wideActions ? 38 : 34;
    final double iconSize = wideActions ? 21 : 19;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: actionSize,
        width: actionSize,
        child: Center(
          child: PopupMenuButton<_CardOverflowAction>(
            tooltip: 'More actions',
            position: PopupMenuPosition.under,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(10),
            onOpened: () {
              AndroidAudioDisplayMode.notifyUserActivity();
              onVisualOverlayChanged?.call(true);
              unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));
            },
            onCanceled: () {
              onVisualOverlayChanged?.call(false);
              unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
            },
            child: SizedBox(
              height: actionSize,
              width: actionSize,
              child: Center(
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: iconSize,
                  color: colorScheme.onSurface.withAlpha(168),
                ),
              ),
            ),
            onSelected: (action) {
              onVisualOverlayChanged?.call(false);
              unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
              switch (action) {
                case _CardOverflowAction.downloadOrDelete:
                  if (isDownloaded) {
                    onDeleteDownload?.call();
                  } else {
                    onDownload?.call();
                  }
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
                case _CardOverflowAction.switchTranslation:
                  onSwitchTranslation?.call();
                  break;
              }
            },
            itemBuilder: (context) {
              return <PopupMenuEntry<_CardOverflowAction>>[
                PopupMenuItem<_CardOverflowAction>(
                  value: _CardOverflowAction.downloadOrDelete,
                  enabled:
                      !isDownloading &&
                      (isDownloaded
                          ? onDeleteDownload != null
                          : onDownload != null),
                  child: _OverflowMenuItem(
                    icon: isDownloading
                        ? Icons.downloading_rounded
                        : isDownloaded
                        ? Icons.delete_outline_rounded
                        : Icons.download_rounded,
                    label: isDownloading
                        ? 'Downloading'
                        : isDownloaded
                        ? 'Delete downloaded ayah'
                        : 'Download ayah',
                  ),
                ),
                if (showTranslation && onSwitchTranslation != null)
                  PopupMenuItem<_CardOverflowAction>(
                    value: _CardOverflowAction.switchTranslation,
                    child: const _OverflowMenuItem(
                      icon: Icons.language_rounded,
                      label: 'Translation language',
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
                      icon: Icons.ios_share_outlined,
                      label: 'Share image',
                    ),
                  ),
              ];
            },
          ),
        ),
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
            20,
            compactShareContent ? 14 : 16,
            20,
            shareImageMode ? (compactShareContent ? 14 : 16) : 20,
          ),
          child: Column(
            mainAxisSize: shareImageMode ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(context),
              SizedBox(height: compactShareContent ? 16 : 20),
              if (basmala != null)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: compactShareContent ? 14 : 16,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
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
              ),
              if (hasTransliteration)
                Padding(
                  padding: EdgeInsets.only(top: compactShareContent ? 12 : 14),
                  child: Text(
                    trimmedTransliteration,
                    textAlign: TextAlign.justify,
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
      children: <Widget>[
        Icon(icon, size: 19, color: colorScheme.onSurface.withAlpha(190)),
        const SizedBox(width: 12),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
