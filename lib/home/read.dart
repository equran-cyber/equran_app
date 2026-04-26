import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageByteFormat, TextBox, lerpDouble;
import 'package:like_button/like_button.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:equran/backend/bookmark_db.dart';
import 'package:equran/backend/library.dart'
    show
        AndroidAudioDisplayMode,
        AudioDownloadService,
        DownloadNotifications,
        FavouritesDB,
        QuranTransliterationService,
        QuranAudioService,
        SettingsDB,
        TafsirService,
        TafsirSource;
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/quran_text.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:equran/utils/translation_display.dart';
import 'package:equran/widgets/library.dart'
    show
        AppSelectionDialog,
        AppSelectionOption,
        ReadProgressBar,
        ReadQuranCard,
        ReadVersePlayerBar;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        PipelineOwner,
        RenderParagraph,
        RenderRepaintBoundary,
        RenderView,
        ScrollDirection,
        ViewConfiguration;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:numberpicker/numberpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';

class _OfflineAudioPlaybackException implements Exception {
  const _OfflineAudioPlaybackException();
}

class _CancelledAudioPlaybackException implements Exception {
  const _CancelledAudioPlaybackException();
}

class ReadPage extends StatefulWidget {
  final int chapter;
  final bool juzMode;
  final int? startVerse;

  const ReadPage({
    super.key,
    required this.chapter,
    this.startVerse,
    this.juzMode = false,
  });

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  static const MethodChannel _readPageChannel = MethodChannel(
    'com.app.equran/read_page',
  );
  static const Size _shareImageSize = Size(1080, 1350);
  static const double _cardSwipeEdgeInset = 40;
  static const double _cardSwipeMinVelocity = 300;
  static const double _cardSwipeMinDistance = 82;
  static const double _cardSwipeAssistDistance = 46;
  static const double _cardSwipeAxisLockRatio = 1.18;
  static const double _playerBarMinimizeDistance = 44;
  static const double _playerBarExpandDistance = 34;
  static const double _playerBarDismissDistance = 52;
  static const double _playerBarMinVelocity = 220;

  final AudioPlayer _versePlayer = AudioPlayer();
  late int _currentVerse;
  late int _currentChapter;
  late ScrollController _scrollController;
  late int _totalVerses;
  late FocusNode _pageFocusNode;
  late bool _viewMode;
  bool _hasSavedOnExit = false;
  bool _playerVisible = false;
  bool _playerMounted = false;
  bool _playerMinimized = false;
  bool _isVersePlaying = false;
  bool _isVerseLoading = false;
  bool _isDownloadingSurahAyahs = false;
  final Set<String> _downloadingAyahKeys = <String>{};
  bool _hasDownloadedSurahAyahs = false;
  bool _hasDownloadedCurrentAyah = false;
  bool _continuousPlayback = false;
  bool _repeatIntervalEnabled = false;
  final Set<String> _preloadingAyahKeys = <String>{};
  int _playbackRequestId = 0;
  int? _playingVerse;
  int _repeatStartVerse = 1;
  int _repeatEndVerse = 1;
  Duration _playerPosition = Duration.zero;
  Duration _playerDuration = Duration.zero;
  final ValueNotifier<Duration> _playerPositionValue = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> _playerDurationValue = ValueNotifier<Duration>(
    Duration.zero,
  );
  StreamSubscription<Duration>? _playerPositionSubscription;
  StreamSubscription<Duration>? _playerDurationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  Timer? _pageScrollProgressTimer;
  Timer? _inlineVerseHighlightTimer;
  final GlobalKey _pageViewViewportKey = GlobalKey();
  final GlobalKey _inlineSurahTextKey = GlobalKey();
  List<int>? _verseTextCumulativeLengths;
  int _verseTextTotalLength = 0;
  String? _inlineSurahTextCache;
  int? _selectedInlineVerse;
  bool _isProgrammaticPageScroll = false;
  bool _isScrubbingProgress = false;
  bool _isPreparingShareImage = false;
  int? _scrubStartVerse;
  double? _scrubStartDx;
  double? _scrubStartDy;
  double _scrubPrecision = 1.0;
  double? _cardSwipeStartX;
  double _cardSwipeDistance = 0;
  double _cardSwipeVerticalDistance = 0;
  double _playerBarDragDistance = 0;
  double _playerCollapseProgress = 0;
  double _playerBarDragStartProgress = 0;
  bool _isDraggingPlayerBar = false;
  int? _transliterationChapter;
  List<String> _chapterTransliterations = const <String>[];

  @override
  void initState() {
    super.initState();
    _viewMode = SettingsDB().get("viewMode", defaultValue: true);

    _scrollController = ScrollController();
    _currentChapter = widget.chapter;
    _currentVerse = widget.startVerse is int ? widget.startVerse! : 1;
    _isDownloadingSurahAyahs = AudioDownloadService()
        .isSurahAyahsDownloadInProgress(_currentChapter);
    unawaited(_refreshSurahAyahDownloadState());
    unawaited(_refreshCurrentAyahDownloadState());
    _pageFocusNode = FocusNode(debugLabel: 'Read Page Keyboard Focus');
    _getTotalVerses();
    unawaited(_loadChapterTransliterations());
    _repeatStartVerse = _currentVerse;
    _repeatEndVerse = _currentVerse;
    _bindVersePlayer();
    if (!_viewMode && _currentVerse > 1) {
      _scrollToInlineVerse(_currentVerse, animate: false, highlight: true);
    }
  }

  @override
  void dispose() {
    if (!_hasSavedOnExit) {
      _syncCurrentVerseWithVisibleText();
      BookmarkDB().addReadingEntry(_currentChapter, _currentVerse);
    }
    unawaited(_setKeepScreenOn(false));
    unawaited(AndroidAudioDisplayMode.setIdleAudioFrameRateEnabled(true));
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
    unawaited(AndroidAudioDisplayMode.setAudioPlaybackActive(false));
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _pageScrollProgressTimer?.cancel();
    _inlineVerseHighlightTimer?.cancel();
    _versePlayer.dispose();
    _playerPositionValue.dispose();
    _playerDurationValue.dispose();
    _scrollController.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _notifyAudioUserActivity() {
    AndroidAudioDisplayMode.notifyUserActivity();
  }

  void _setPlayerMinimizedState(bool minimized) {
    _playerMinimized = minimized;
    unawaited(AndroidAudioDisplayMode.setIdleAudioFrameRateEnabled(!minimized));
  }

  Future<T> _withLowFpsSuppressed<T>(Future<T> Function() action) async {
    AndroidAudioDisplayMode.notifyUserActivity();
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));
    try {
      return await action();
    } finally {
      unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
    }
  }

  void _setPlayerPosition(Duration position) {
    _playerPosition = position;
    _playerPositionValue.value = position;
  }

  void _setPlayerDuration(Duration duration) {
    _playerDuration = duration;
    _playerDurationValue.value = duration;
  }

  void _syncPageProgressFromScroll() {
    if (_viewMode ||
        !_scrollController.hasClients ||
        _isProgrammaticPageScroll) {
      return;
    }

    _pageScrollProgressTimer?.cancel();
    _pageScrollProgressTimer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || _viewMode || _isProgrammaticPageScroll) return;
      final int visibleVerse = _verseForCurrentScrollOffset();
      if (visibleVerse == _currentVerse) return;
      _currentVerse = visibleVerse;
      _updateDB();
    });
  }

  void _ensureVerseTextMetrics() {
    if (_verseTextCumulativeLengths != null) return;

    _inlineSurahText();
  }

  String _inlineSurahText() {
    final String? cachedText = _inlineSurahTextCache;
    if (cachedText != null) return cachedText;

    final StringBuffer buffer = StringBuffer();
    final List<int> lengths = <int>[0];
    int total = 0;
    for (int verse = 1; verse <= _totalVerses; verse++) {
      final String segment = _inlineVerseTextSegment(verse);
      buffer.write(segment);
      total += segment.length;
      lengths.add(total);
    }

    _verseTextCumulativeLengths = lengths;
    _verseTextTotalLength = total;
    _inlineSurahTextCache = buffer.toString();
    return _inlineSurahTextCache!;
  }

  void _clearVerseTextMetrics() {
    _verseTextCumulativeLengths = null;
    _verseTextTotalLength = 0;
    _inlineSurahTextCache = null;
  }

  Future<void> _loadChapterTransliterations() async {
    final int chapter = _currentChapter;
    final List<String> transliterations = await QuranTransliterationService
        .instance
        .versesForSurah(chapter);
    if (!mounted || chapter != _currentChapter) return;
    setState(() {
      _transliterationChapter = chapter;
      _chapterTransliterations = transliterations;
    });
  }

  String _transliterationForVerse(int verse) {
    if (_transliterationChapter != _currentChapter) return '';
    if (verse < 1 || verse > _chapterTransliterations.length) return '';
    return _chapterTransliterations[verse - 1].trim();
  }

  String _cardTransliterationForVerse(int verse) {
    final String cached = _transliterationForVerse(verse);
    if (cached.isNotEmpty) return cached;

    unawaited(_loadChapterTransliterations());
    return '';
  }

  int _verseForCurrentScrollOffset() {
    if (!_scrollController.hasClients) {
      return _currentVerse;
    }

    final BuildContext? textContext = _inlineSurahTextKey.currentContext;
    final BuildContext? viewportContext = _pageViewViewportKey.currentContext;
    final RenderObject? textRenderObject = textContext?.findRenderObject();
    final RenderObject? viewportRenderObject = viewportContext
        ?.findRenderObject();

    if (textRenderObject is RenderParagraph &&
        viewportRenderObject is RenderBox) {
      final Offset textGlobalTopLeft = textRenderObject.localToGlobal(
        Offset.zero,
      );
      final double viewportTop = viewportRenderObject
          .localToGlobal(Offset.zero)
          .dy;
      final double localY = (viewportTop + 24 - textGlobalTopLeft.dy)
          .clamp(0.0, textRenderObject.size.height)
          .toDouble();
      return _verseForLocalTextY(textRenderObject, localY);
    }

    _ensureVerseTextMetrics();
    final List<int> lengths = _verseTextCumulativeLengths ?? <int>[0];
    if (_verseTextTotalLength <= 0 || lengths.length <= 1) return _currentVerse;

    final ScrollPosition position = _scrollController.position;
    final double maxScrollExtent = position.maxScrollExtent;
    if (maxScrollExtent <= 0) return 1;

    final double scrollFraction = (position.pixels / maxScrollExtent).clamp(
      0.0,
      1.0,
    );
    final int targetLength = (_verseTextTotalLength * scrollFraction).round();

    int low = 1;
    int high = lengths.length - 1;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (lengths[mid] < targetLength) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    return low.clamp(1, _totalVerses).toInt();
  }

  void _syncCurrentVerseWithVisibleText({bool persist = false}) {
    if (_viewMode) return;

    final int visibleVerse = _verseForCurrentScrollOffset();
    if (visibleVerse == _currentVerse) return;
    _currentVerse = visibleVerse;
    if (persist) {
      _updateDB();
    }
  }

  void _highlightInlineVerseBriefly(
    int verse, {
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    if (_viewMode) return;
    if (verse < 1 || verse > _totalVerses) return;

    _inlineVerseHighlightTimer?.cancel();
    setState(() {
      _selectedInlineVerse = verse;
    });
    _inlineVerseHighlightTimer = Timer(duration, () {
      if (!mounted || _selectedInlineVerse != verse) return;
      setState(() {
        _selectedInlineVerse = null;
      });
    });
  }

  double _scrollOffsetForVerse(int verse) {
    if (!_scrollController.hasClients) return 0;

    final BuildContext? textContext = _inlineSurahTextKey.currentContext;
    final BuildContext? viewportContext = _pageViewViewportKey.currentContext;
    final RenderObject? textRenderObject = textContext?.findRenderObject();
    final RenderObject? viewportRenderObject = viewportContext
        ?.findRenderObject();

    final ScrollPosition position = _scrollController.position;
    if (textRenderObject is! RenderParagraph ||
        viewportRenderObject is! RenderBox) {
      return _estimatedScrollOffsetForVerse(verse);
    }

    final List<TextBox> boxes = _textBoxesForVerse(textRenderObject, verse);
    if (boxes.isEmpty) {
      return _estimatedScrollOffsetForVerse(verse);
    }

    final double verseTop = boxes.map((TextBox box) => box.top).reduce(min);
    final double verseGlobalY = textRenderObject
        .localToGlobal(Offset(0, verseTop))
        .dy;
    final double viewportTop = viewportRenderObject
        .localToGlobal(Offset.zero)
        .dy;

    return (position.pixels + verseGlobalY - viewportTop - 12)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  double _estimatedScrollOffsetForVerse(int verse) {
    _ensureVerseTextMetrics();
    final List<int> lengths = _verseTextCumulativeLengths ?? <int>[0];
    if (_verseTextTotalLength <= 0 || lengths.length <= 1) return 0;

    final int safeVerse = verse.clamp(1, _totalVerses).toInt();
    final int previousLength = lengths[safeVerse - 1];
    final double scrollFraction = previousLength / _verseTextTotalLength;
    final ScrollPosition position = _scrollController.position;
    return (position.maxScrollExtent * scrollFraction)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  ({int start, int end}) _textRangeForVerse(int verse) {
    _ensureVerseTextMetrics();
    final List<int> lengths = _verseTextCumulativeLengths ?? <int>[0];
    final int safeVerse = verse.clamp(1, _totalVerses).toInt();
    if (lengths.length <= safeVerse) return (start: 0, end: 0);

    final int start = (lengths[safeVerse - 1] + 1)
        .clamp(0, _verseTextTotalLength)
        .toInt();
    final int end = (lengths[safeVerse] - 3)
        .clamp(start, _verseTextTotalLength)
        .toInt();
    return (start: start, end: end);
  }

  List<TextBox> _textBoxesForVerse(RenderParagraph paragraph, int verse) {
    final range = _textRangeForVerse(verse);
    if (range.start >= range.end) return const <TextBox>[];

    return paragraph.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
    );
  }

  int _verseForLocalTextY(RenderParagraph paragraph, double localY) {
    int closestVerse = 1;
    double closestTop = double.negativeInfinity;

    for (int verse = 1; verse <= _totalVerses; verse++) {
      final List<TextBox> boxes = _textBoxesForVerse(paragraph, verse);
      if (boxes.isEmpty) continue;

      for (final TextBox box in boxes) {
        if (localY >= box.top - 0.5 && localY <= box.bottom + 0.5) {
          return verse;
        }
      }

      final double verseTop = boxes.map((TextBox box) => box.top).reduce(min);
      if (verseTop <= localY && verseTop >= closestTop) {
        closestVerse = verse;
        closestTop = verseTop;
      } else if (verseTop > localY && closestTop.isFinite) {
        break;
      }
    }

    return closestVerse.clamp(1, _totalVerses).toInt();
  }

  int _verseForTextOffset(int textOffset) {
    _ensureVerseTextMetrics();
    final List<int> lengths = _verseTextCumulativeLengths ?? <int>[0];
    if (_verseTextTotalLength <= 0 || lengths.length <= 1) {
      return _currentVerse;
    }

    final int offset = textOffset.clamp(0, _verseTextTotalLength).toInt();
    int low = 1;
    int high = lengths.length - 1;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (lengths[mid] <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    return low.clamp(1, _totalVerses).toInt();
  }

  String _inlineVerseTextSegment(int verse) {
    return inlineQuranVerseSegment(_currentChapter, verse);
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    // Define margin values for different screen sizes
    double marginValue;
    if (screenSize.width > 1200) {
      marginValue = 90.0; // Large screen
    } else if (screenSize.width > 700) {
      marginValue = 40.0; // Medium screen
    } else {
      marginValue = 8.0; // Small screen
    }
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _saveProgressOnExit();
        }
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _notifyAudioUserActivity(),
        onPointerMove: (_) => _notifyAudioUserActivity(),
        onPointerSignal: (_) => _notifyAudioUserActivity(),
        child: Focus(
          autofocus: true,
          focusNode: _pageFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }

            _notifyAudioUserActivity();

            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _increase();
              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _decrease();
              return KeyEventResult.handled;
            }

            return KeyEventResult.ignored;
          },
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: ResponsiveNav.toolbarHeight(context),
              iconTheme: IconThemeData(size: ResponsiveNav.iconSize(context)),
              leading: const BackButton(),
              title: Text(quran.getSurahName(_currentChapter)),
              centerTitle: true,
              actions: <Widget>[
                if (!_viewMode)
                  IconButton(
                    tooltip: _isVersePlaying && _playingVerse == _currentVerse
                        ? 'Pause'
                        : 'Play current ayah',
                    onPressed: _togglePageViewPlayback,
                    icon: Icon(
                      _isVersePlaying && _playingVerse == _currentVerse
                          ? Icons.pause_circle_rounded
                          : Icons.play_circle_rounded,
                      size: 24,
                    ),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                  ),
                IconButton(
                  tooltip: _hasDownloadedSurahAyahs
                      ? 'All ayahs downloaded'
                      : 'Download surah ayahs',
                  onPressed: _isDownloadingSurahAyahs
                      ? null
                      : _confirmDownloadCurrentSurahAyahs,
                  icon: _isDownloadingSurahAyahs
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _hasDownloadedSurahAyahs
                              ? Icons.offline_pin_rounded
                              : Icons.download_for_offline_rounded,
                          size: 22,
                        ),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
                IconButton(
                  tooltip: 'Go to ayah',
                  onPressed: () => _showJumpToVerseDialog(context),
                  icon: const Icon(Icons.double_arrow_outlined, size: 22),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
                const SizedBox(width: 10),
              ],
            ),
            body: _viewMode
                ? cardView(marginValue: marginValue)
                : listView(marginValue: marginValue),
          ),
        ),
      ),
    );
  }

  void _bindVersePlayer() {
    _playerPositionSubscription = _versePlayer.onPositionChanged.listen((
      position,
    ) {
      if (!mounted) return;
      _setPlayerPosition(position);
    });

    _playerDurationSubscription = _versePlayer.onDurationChanged.listen((
      duration,
    ) {
      if (!mounted) return;
      _setPlayerDuration(duration);
    });

    _playerStateSubscription = _versePlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() {
        _isVersePlaying = state == PlayerState.playing;
        if (state == PlayerState.playing || state == PlayerState.paused) {
          _isVerseLoading = false;
        }
      });
      unawaited(_updateKeepScreenOn());
      unawaited(
        AndroidAudioDisplayMode.setAudioPlaybackActive(_isVersePlaying),
      );
    });

    _playerCompleteSubscription = _versePlayer.onPlayerComplete.listen((
      _,
    ) async {
      await _handleVerseComplete();
    });
  }

  Future<void> _showJumpToVerseDialog(BuildContext context) async {
    if (!_viewMode) {
      _syncCurrentVerseWithVisibleText(persist: true);
    }

    final TextEditingController controller = TextEditingController(
      text: _currentVerse.toString(),
    );
    final FocusNode focusNode = FocusNode();
    String? errorText;
    bool sheetOpen = true;
    bool initialFocusRequested = false;
    bool isSubmitting = false;

    AndroidAudioDisplayMode.notifyUserActivity();
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));

    int? selectedVerse;

    try {
      selectedVerse = await showModalBottomSheet<int>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        requestFocus: false,
        builder: (sheetContext) {
          final ThemeData theme = Theme.of(sheetContext);
          final ColorScheme colorScheme = theme.colorScheme;

          if (!initialFocusRequested) {
            initialFocusRequested = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(
                Future<void>.delayed(const Duration(milliseconds: 220), () {
                  if (sheetOpen && focusNode.canRequestFocus) {
                    focusNode.requestFocus();
                  }
                }),
              );
            });
          }

          Future<void> submit(StateSetter setSheetState) async {
            if (isSubmitting) return;
            final int? value = int.tryParse(controller.text.trim());

            if (value == null || value < 1 || value > _totalVerses) {
              setSheetState(() {
                errorText = 'Enter a verse between 1 and $_totalVerses';
              });
              return;
            }

            isSubmitting = true;
            focusNode.unfocus();
            if (Navigator.of(sheetContext).canPop()) {
              Navigator.of(sheetContext).pop(value);
            }
          }

          return StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Go to ayah',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter a verse number from 1 to $_totalVerses',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.go,
                      textAlign: TextAlign.center,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: 'Verse number',
                        errorText: errorText,
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onChanged: (_) {
                        if (errorText != null) {
                          setSheetState(() {
                            errorText = null;
                          });
                        }
                      },
                      onSubmitted: (_) => submit(setSheetState),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => submit(setSheetState),
                      child: const Text('Go'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      sheetOpen = false;
      unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
      await WidgetsBinding.instance.endOfFrame;
      controller.dispose();
      focusNode.dispose();
    }

    if (selectedVerse == null || !mounted) return;

    final bool shouldRetargetContinuousPlayback =
        _isVersePlaying &&
        _continuousPlayback &&
        !_repeatIntervalEnabled &&
        selectedVerse != (_playingVerse ?? _currentVerse);
    _setVerse(selectedVerse);
    if (!_viewMode) {
      _scrollToInlineVerse(selectedVerse, highlight: true);
    } else {
      _scrollUp();
    }
    _updateDB();

    if (shouldRetargetContinuousPlayback) {
      unawaited(
        _playVerse(
          _currentChapter,
          selectedVerse,
          continuous: true,
          smoothScroll: !_viewMode,
        ),
      );
    }
  }

  Future<void> _saveProgressOnExit() async {
    if (_hasSavedOnExit) return;

    _hasSavedOnExit = true;
    _syncCurrentVerseWithVisibleText();
    await BookmarkDB().addReadingEntry(_currentChapter, _currentVerse);
  }

  Future<void> _setKeepScreenOn(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await _readPageChannel.invokeMethod<void>(
        'setKeepScreenOn',
        <String, bool>{'enabled': enabled},
      );
    } catch (_) {
      // Ignore platform-channel failures on unsupported builds.
    }
  }

  Future<void> _updateKeepScreenOn() async {
    await _setKeepScreenOn(
      _playerVisible && (_continuousPlayback || _repeatIntervalEnabled),
    );
  }

  Future<void> _refreshCurrentAyahDownloadState() async {
    final bool hasAyah = await AudioDownloadService().hasAyah(
      _currentChapter,
      _currentVerse,
    );
    if (!mounted) return;
    setState(() {
      _hasDownloadedCurrentAyah = hasAyah;
    });
  }

  Future<void> _playVerse(
    int surah,
    int verse, {
    bool continuous = false,
    bool smoothScroll = false,
    bool preservePlayerPresentationState = false,
  }) async {
    if (_isVerseLoading) return;

    AndroidAudioDisplayMode.notifyUserActivity();
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));

    final int requestId = ++_playbackRequestId;
    final bool shouldPreservePresentation =
        preservePlayerPresentationState && _playerMounted && _playerVisible;
    final bool nextPlayerMinimized = shouldPreservePresentation
        ? _playerMinimized
        : false;
    final double nextPlayerCollapseProgress = shouldPreservePresentation
        ? _playerCollapseProgress
        : 0;
    setState(() {
      _playerVisible = true;
      _playerMounted = true;
      _setPlayerMinimizedState(false);
      _playerMinimized = nextPlayerMinimized;
      _playerCollapseProgress = nextPlayerCollapseProgress;
      _isDraggingPlayerBar = false;
      _isVerseLoading = true;
      _continuousPlayback = continuous;
      if (!_repeatIntervalEnabled) {
        _repeatStartVerse = verse;
        _repeatEndVerse = verse;
      }
      _playingVerse = verse;
      _currentVerse = verse;
      _setPlayerPosition(Duration.zero);
      _setPlayerDuration(Duration.zero);
    });
    _updateDB();
    _scrollToVerseIfNeeded(verse, smooth: smoothScroll);

    try {
      await _playVerseWithRetry(surah, verse, requestId);
      if (continuous && mounted && requestId == _playbackRequestId) {
        unawaited(_preloadNextContinuousAyahs(surah, verse));
      }
    } on _CancelledAudioPlaybackException {
      return;
    } on _OfflineAudioPlaybackException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are offline. Download this ayah or reconnect to stream it.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to play ayah audio.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerseLoading = false;
        });
      }
      unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
    }
  }

  Future<void> _playVerseWithRetry(int surah, int verse, int requestId) async {
    const List<Duration> retryDelays = <Duration>[
      Duration(milliseconds: 350),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1400),
    ];

    Object? lastError;
    for (int attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        _throwIfPlaybackRequestCancelled(requestId);
        await _playVerseSource(surah, verse, requestId);
        return;
      } on _CancelledAudioPlaybackException {
        rethrow;
      } on _OfflineAudioPlaybackException {
        rethrow;
      } catch (error) {
        lastError = error;
        _throwIfPlaybackRequestCancelled(requestId);
        if (!await _hasInternetConnection()) {
          _throwIfPlaybackRequestCancelled(requestId);
          throw const _OfflineAudioPlaybackException();
        }
        if (attempt == retryDelays.length) break;
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }

    Error.throwWithStackTrace(
      lastError ?? Exception('Audio playback failed.'),
      StackTrace.current,
    );
  }

  Future<void> _playVerseSource(int surah, int verse, int requestId) async {
    await _versePlayer.stop();
    _throwIfPlaybackRequestCancelled(requestId);
    final double rate = _playbackRate();
    await _versePlayer.setPlaybackRate(rate);
    final offlineFile = await AudioDownloadService().ayahFile(surah, verse);
    _throwIfPlaybackRequestCancelled(requestId);
    if (!kIsWeb && offlineFile.existsSync()) {
      await _versePlayer.play(DeviceFileSource(offlineFile.path));
    } else {
      final String url = await QuranAudioService().getAyahUrl(surah, verse);
      _throwIfPlaybackRequestCancelled(requestId);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
        final Uint8List bytes = await _downloadVerseAudioBytes(url);
        _throwIfPlaybackRequestCancelled(requestId);
        await _versePlayer.play(BytesSource(bytes));
      } else {
        await _versePlayer.play(UrlSource(url));
      }
    }
    await _versePlayer.setPlaybackRate(rate);
  }

  Future<Uint8List> _downloadVerseAudioBytes(String url) async {
    final http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load audio: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  Future<void> _preloadNextContinuousAyahs(int surah, int verse) async {
    final AudioDownloadService downloads = AudioDownloadService();
    final int totalVerses = quran.getVerseCount(surah);
    for (
      int nextVerse = verse + 1;
      nextVerse <= min(verse + 2, totalVerses);
      nextVerse++
    ) {
      final String key = '$surah-$nextVerse';
      if (_preloadingAyahKeys.contains(key)) continue;
      _preloadingAyahKeys.add(key);
      try {
        if (!await downloads.hasAyah(surah, nextVerse)) {
          await downloads.downloadAyah(surah, nextVerse);
        }
      } catch (_) {
        // Best-effort preload; foreground playback should never wait on this.
      } finally {
        _preloadingAyahKeys.remove(key);
      }
    }
  }

  void _throwIfPlaybackRequestCancelled(int requestId) {
    if (!mounted || requestId != _playbackRequestId) {
      throw const _CancelledAudioPlaybackException();
    }
  }

  Future<bool> _hasInternetConnection() async {
    if (kIsWeb) return true;

    final http.Client client = http.Client();
    try {
      final http.Response response = await client
          .head(Uri.parse('https://quranapi.pages.dev/api/1/1.json'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  double _playbackRate() {
    final dynamic value = SettingsDB().get("playbackRate", defaultValue: 1.0);
    if (value is num) {
      return value.toDouble().clamp(0.5, 2.0);
    }
    return 1.0;
  }

  Future<void> _handleVerseComplete() async {
    final int completedVerse = _playingVerse ?? _currentVerse;
    if (_repeatIntervalEnabled) {
      final int nextVerse = completedVerse >= _repeatEndVerse
          ? _repeatStartVerse
          : completedVerse + 1;
      await _playVerse(
        _currentChapter,
        nextVerse,
        smoothScroll: true,
        preservePlayerPresentationState: true,
      );
      return;
    }

    if (_continuousPlayback && completedVerse < _totalVerses) {
      await _playVerse(
        _currentChapter,
        completedVerse + 1,
        continuous: true,
        smoothScroll: true,
        preservePlayerPresentationState: true,
      );
      return;
    }

    if (!mounted) return;
    await _stopBottomPlayer();
  }

  Future<void> _toggleBottomPlayer() async {
    if (_isVerseLoading) return;
    if (_isVersePlaying) {
      await _versePlayer.pause();
      return;
    }

    if (_playingVerse != null && _playerPosition > Duration.zero) {
      await _versePlayer.resume();
      return;
    }

    await _playVerse(
      _currentChapter,
      _playingVerse ?? _currentVerse,
      continuous: _continuousPlayback,
    );
  }

  Future<void> _playAdjacentPageViewAyah(int direction) async {
    if (_isVerseLoading) return;

    final int currentVerse = _playingVerse ?? _currentVerse;
    final int targetVerse = currentVerse + direction;
    if (targetVerse < 1 || targetVerse > _totalVerses) return;

    await _playVerse(
      _currentChapter,
      targetVerse,
      continuous: _continuousPlayback,
      smoothScroll: true,
    );
  }

  void _togglePageViewPlayback() {
    if (!_viewMode) {
      _syncCurrentVerseWithVisibleText(persist: true);
    }

    if (_isVersePlaying && _playingVerse == _currentVerse) {
      unawaited(_toggleBottomPlayer());
      return;
    }

    final bool continuous = !_viewMode;
    if (_viewMode) {
      _continuousPlayback = false;
    }
    unawaited(
      _playVerse(_currentChapter, _currentVerse, continuous: continuous),
    );
  }

  Future<void> _downloadCurrentSurahAyahs() async {
    if (_isDownloadingSurahAyahs) return;

    setState(() {
      _isDownloadingSurahAyahs = true;
    });

    final int notificationId = DownloadNotifications.notificationId(
      'surah-ayahs-$_currentChapter',
    );
    final String surahName = quran.getSurahName(_currentChapter);
    final String title = 'Downloading $surahName ayahs';

    try {
      await DownloadNotifications.progress(
        id: notificationId,
        title: title,
        progress: null,
      );
      await AudioDownloadService().downloadSurahAyahs(
        _currentChapter,
        onProgress: (progress) => unawaited(
          DownloadNotifications.progress(
            id: notificationId,
            title: title,
            progress: progress.fraction,
          ),
        ),
      );
      await DownloadNotifications.complete(
        id: notificationId,
        title: 'Downloaded $surahName ayahs',
      );
      await _refreshSurahAyahDownloadState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded all ayahs for $surahName')),
        );
      }
    } catch (_) {
      await DownloadNotifications.fail(
        id: notificationId,
        title: 'Failed to download $surahName ayahs',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download $surahName ayahs.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingSurahAyahs = false;
        });
      }
    }
  }

  Future<void> _confirmDownloadCurrentSurahAyahs() async {
    final String surahName = quran.getSurahName(_currentChapter);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.download_for_offline_rounded),
        title: const Text('Download All Ayahs?'),
        content: Text(
          'Download all ayah audio for $surahName for offline listening?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _downloadCurrentSurahAyahs();
  }

  Future<void> _downloadCurrentAyah() async {
    final int chapter = _currentChapter;
    final int verse = _currentVerse;
    final String downloadKey = '$chapter-$verse';
    if (_downloadingAyahKeys.contains(downloadKey)) return;

    try {
      setState(() {
        _downloadingAyahKeys.add(downloadKey);
      });

      final int notificationId = DownloadNotifications.notificationId(
        'ayah-$chapter-$verse',
      );
      final String title = 'Downloading ayah $chapter:$verse';
      await DownloadNotifications.progress(
        id: notificationId,
        title: title,
        progress: null,
      );
      await AudioDownloadService().downloadAyah(
        chapter,
        verse,
        onProgress: (progress) => unawaited(
          DownloadNotifications.progress(
            id: notificationId,
            title: title,
            progress: progress.fraction,
          ),
        ),
      );
      await DownloadNotifications.complete(
        id: notificationId,
        title: 'Downloaded ayah $chapter:$verse',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ayah $chapter:$verse')),
      );
    } catch (_) {
      await DownloadNotifications.fail(
        id: DownloadNotifications.notificationId('ayah-$chapter-$verse'),
        title: 'Failed to download ayah $chapter:$verse',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download ayah audio.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingAyahKeys.remove(downloadKey);
        });
      }
      unawaited(_refreshCurrentAyahDownloadState());
    }
  }

  Future<void> _confirmDeleteCurrentAyahDownload() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Delete Downloaded Ayah?'),
        content: Text(
          'This will remove ayah $_currentChapter:$_currentVerse from offline storage.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _deleteCurrentAyahDownload();
  }

  Future<void> _deleteCurrentAyahDownload() async {
    try {
      await AudioDownloadService().deleteAyah(_currentChapter, _currentVerse);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ayah $_currentChapter:$_currentVerse audio'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete downloaded ayah.')),
      );
    } finally {
      await _refreshCurrentAyahDownloadState();
      await _refreshSurahAyahDownloadState();
    }
  }

  Future<void> _refreshSurahAyahDownloadState() async {
    if (kIsWeb) return;

    final AudioDownloadService downloads = AudioDownloadService();
    final int chapter = _currentChapter;
    final int totalVerses = quran.getVerseCount(chapter);
    for (int ayah = 1; ayah <= totalVerses; ayah++) {
      if (!await downloads.hasAyah(chapter, ayah)) {
        if (mounted && chapter == _currentChapter) {
          setState(() {
            _hasDownloadedSurahAyahs = false;
          });
        }
        return;
      }
    }

    if (mounted && chapter == _currentChapter) {
      setState(() {
        _hasDownloadedSurahAyahs = true;
      });
    }
  }

  Future<void> _stopBottomPlayer() async {
    if (!mounted) return;
    _playbackRequestId++;
    setState(() {
      _playerVisible = false;
      _setPlayerMinimizedState(false);
      _playerMinimized = false;
      _playerCollapseProgress = 0;
      _isDraggingPlayerBar = false;
      _isVersePlaying = false;
      _isVerseLoading = false;
      _continuousPlayback = false;
      _repeatIntervalEnabled = false;
      _playingVerse = null;
      _setPlayerPosition(Duration.zero);
      _setPlayerDuration(Duration.zero);
    });
    await _versePlayer.stop();
    await _setKeepScreenOn(false);
    await AndroidAudioDisplayMode.setAudioPlaybackActive(false);
  }

  void _toggleContinuousPlayback(bool value) {
    setState(() {
      _continuousPlayback = value;
      if (value) {
        _repeatIntervalEnabled = false;
      }
      _playerVisible = true;
      _playerMounted = true;
      _setPlayerMinimizedState(false);
      _playerMinimized = false;
      _playerCollapseProgress = 0;
      _isDraggingPlayerBar = false;
      _playingVerse ??= _currentVerse;
      if (value) {
        _repeatStartVerse = _currentVerse;
        _repeatEndVerse = _currentVerse;
      }
    });
    unawaited(_updateKeepScreenOn());
  }

  Future<void> _showRepeatIntervalSheet() async {
    _notifyAudioUserActivity();
    int start = _repeatIntervalEnabled ? _repeatStartVerse : _currentVerse;
    int end = _repeatIntervalEnabled ? _repeatEndVerse : _currentVerse;

    final bool? enabled = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _notifyAudioUserActivity(),
              onPointerMove: (_) => _notifyAudioUserActivity(),
              onPointerSignal: (_) => _notifyAudioUserActivity(),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Repeat Ayah Interval',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Column(
                            children: <Widget>[
                              const Text('From'),
                              NumberPicker(
                                minValue: 1,
                                maxValue: _totalVerses,
                                value: start,
                                onChanged: (value) {
                                  _notifyAudioUserActivity();
                                  setSheetState(() {
                                    start = value;
                                    if (end < start) end = start;
                                  });
                                },
                              ),
                            ],
                          ),
                          Column(
                            children: <Widget>[
                              const Text('To'),
                              NumberPicker(
                                minValue: 1,
                                maxValue: _totalVerses,
                                value: end,
                                onChanged: (value) {
                                  _notifyAudioUserActivity();
                                  setSheetState(() {
                                    end = value;
                                    if (start > end) start = end;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _notifyAudioUserActivity();
                                Navigator.of(context).pop(false);
                              },
                              child: const Text('Disable'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                _notifyAudioUserActivity();
                                Navigator.of(context).pop(true);
                              },
                              child: const Text('Repeat Interval'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (enabled == null) return;
    if (!mounted) return;
    if (!enabled) {
      setState(() {
        _repeatIntervalEnabled = false;
      });
      unawaited(_updateKeepScreenOn());
      return;
    }

    final int currentPlayingVerse = _playingVerse ?? _currentVerse;
    final bool shouldKeepCurrentPlayback =
        _isVersePlaying && currentPlayingVerse == start;

    setState(() {
      _repeatIntervalEnabled = true;
      _continuousPlayback = false;
      _playerVisible = true;
      _playerMounted = true;
      _repeatStartVerse = start;
      _repeatEndVerse = end;
      _playingVerse = shouldKeepCurrentPlayback ? currentPlayingVerse : start;
    });
    unawaited(_updateKeepScreenOn());
    if (shouldKeepCurrentPlayback) {
      return;
    }
    await _playVerse(_currentChapter, start);
  }

  Future<void> _seekBottomPlayer(double value) async {
    if (_playerDuration.inMilliseconds <= 0) return;
    final int milliseconds = (_playerDuration.inMilliseconds * value).round();
    await _versePlayer.seek(Duration(milliseconds: milliseconds));
  }

  void _scrollToVerseIfNeeded(int verse, {bool smooth = false}) {
    if (_viewMode) {
      _scrollUp();
      return;
    }

    _scrollToInlineVerse(verse, smooth: smooth);
  }

  void _scrollToInlineVerse(
    int verse, {
    bool animate = true,
    bool smooth = false,
    bool highlight = false,
  }) {
    if (_viewMode) {
      _scrollUp();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;

      _isProgrammaticPageScroll = true;
      try {
        final double offset = _scrollOffsetForVerse(verse);
        if (animate) {
          await _scrollController.animateTo(
            offset,
            duration: smooth
                ? const Duration(milliseconds: 700)
                : const Duration(milliseconds: 320),
            curve: smooth ? Curves.easeInOutCubic : Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(offset);
        }
      } finally {
        if (mounted) {
          _isProgrammaticPageScroll = false;
          if (highlight) {
            _highlightInlineVerseBriefly(verse);
          }
        }
      }
    });
  }

  void _increase() {
    _vibrate();
    _scrollUp();
    if (!_viewMode) {
      _goToNextSurah();
      return;
    }

    if (_playerMounted) {
      _stopBottomPlayer();
    }

    if (_currentVerse != _totalVerses) {
      _incrementVerse();
      _updateDB();
    } else {
      // Surah completed: remove its last-read progress, then move to next chapter.
      BookmarkDB().delete(_currentChapter);
      _reset();
      if (_currentChapter != 114) {
        _incrementChapter();
      } else {
        _resetChapter();
      }
      _getTotalVerses();
      _updateDB();
    }
  }

  void _decrease() {
    _vibrate();
    _scrollUp();
    if (!_viewMode) {
      _goToPreviousSurah();
      return;
    }

    if (_playerMounted) {
      _stopBottomPlayer();
    }

    if (_currentVerse != 1) {
      _decrementVerse();
      _updateDB();
    } else {
      _goToPreviousSurah();
    }
  }

  void _goToNextSurah() {
    if (_playerMounted || _playingVerse != null) {
      unawaited(_stopBottomPlayer());
    }
    BookmarkDB().delete(_currentChapter);
    _clearVerseTextMetrics();
    setState(() {
      _currentChapter = _currentChapter == 114 ? 1 : _currentChapter + 1;
      _currentVerse = 1;
      _totalVerses = quran.getVerseCount(_currentChapter);
      _repeatStartVerse = 1;
      _repeatEndVerse = 1;
      _isDownloadingSurahAyahs = AudioDownloadService()
          .isSurahAyahsDownloadInProgress(_currentChapter);
      _hasDownloadedSurahAyahs = false;
    });
    unawaited(_refreshSurahAyahDownloadState());
    unawaited(_loadChapterTransliterations());
    _updateDB();
  }

  void _goToPreviousSurah() {
    if (_currentChapter == 1) return;
    if (_playerMounted || _playingVerse != null) {
      unawaited(_stopBottomPlayer());
    }
    _clearVerseTextMetrics();
    final int previousChapter = _currentChapter - 1;
    setState(() {
      _currentChapter = previousChapter;
      _totalVerses = quran.getVerseCount(_currentChapter);
      _currentVerse = _totalVerses;
      _repeatStartVerse = _currentVerse;
      _repeatEndVerse = _currentVerse;
      _isDownloadingSurahAyahs = AudioDownloadService()
          .isSurahAyahsDownloadInProgress(_currentChapter);
      _hasDownloadedSurahAyahs = false;
    });
    unawaited(_refreshSurahAyahDownloadState());
    unawaited(_refreshCurrentAyahDownloadState());
    unawaited(_loadChapterTransliterations());
    _updateDB();
  }

  void _incrementVerse() {
    setState(() {
      _currentVerse++;
    });
  }

  void _setVerse(int value) {
    setState(() {
      _currentVerse = value;
    });
    unawaited(_refreshCurrentAyahDownloadState());
  }

  void _decrementVerse() {
    setState(() {
      _currentVerse--;
    });
  }

  void _reset() {
    setState(() {
      _currentVerse = 1;
    });
  }

  void _getTotalVerses() {
    _clearVerseTextMetrics();
    setState(() {
      _totalVerses = quran.getVerseCount(_currentChapter);
    });
  }

  void _incrementChapter() {
    _clearVerseTextMetrics();
    setState(() {
      _currentChapter++;
    });
    unawaited(_loadChapterTransliterations());
  }

  void _resetChapter() {
    _clearVerseTextMetrics();
    setState(() {
      _currentChapter = 1;
    });
    unawaited(_loadChapterTransliterations());
  }

  void _vibrate() async {
    if (SettingsDB().get("vibration", defaultValue: true) != true) return;
    if (kIsWeb) return;

    final bool supportedPlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!supportedPlatform) return;

    try {
      final bool hasVibrator = await Vibration.hasVibrator();
      if (!hasVibrator) return;
      await Vibration.vibrate(duration: 10);
    } catch (_) {
      // Ignore vibration failures on unsupported platforms/devices.
    }
  }

  void _scrollUp() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
  }

  void _updateDB() {
    BookmarkDB().addReadingEntry(_currentChapter, _currentVerse);
    unawaited(_refreshCurrentAyahDownloadState());
  }

  void _updateVerseFromProgress({
    required double localDx,
    required double localDy,
    required double width,
    bool vibrateOnChange = false,
  }) {
    if (_totalVerses <= 0 || width <= 0) return;

    final double startDx = _scrubStartDx ?? localDx;
    final double startDy = _scrubStartDy ?? localDy;
    final int anchorVerse = _scrubStartVerse ?? _currentVerse;
    final double downwardOffset = (localDy - startDy).clamp(
      0.0,
      double.infinity,
    );

    double precision = 1.0;
    if (downwardOffset > 120) {
      precision = 0.12;
    } else if (downwardOffset > 80) {
      precision = 0.2;
    } else if (downwardOffset > 40) {
      precision = 0.35;
    } else if (downwardOffset > 16) {
      precision = 0.6;
    }

    if ((precision - _scrubPrecision).abs() > 0.0001) {
      _scrubPrecision = precision;
      _scrubStartDx = localDx;
      _scrubStartDy = localDy;
      _scrubStartVerse = _currentVerse;
      return;
    }

    final double verseDelta =
        (((localDx - startDx) * precision) / width) * (_totalVerses - 1);
    final int preciseTargetVerse = (anchorVerse + verseDelta.round()).clamp(
      1,
      _totalVerses,
    );

    if (preciseTargetVerse == _currentVerse) return;

    _setVerse(preciseTargetVerse);
    _updateDB();

    if (vibrateOnChange) {
      _vibrate();
    }
  }

  Widget _buildProgressBar(double marginValue) {
    return ReadProgressBar(
      marginValue: marginValue,
      currentVerse: _currentVerse,
      totalVerses: _totalVerses,
      isScrubbing: _isScrubbingProgress,
      scrubStartVerse: _scrubStartVerse,
      onScrubStart: _handleProgressScrubStart,
      onScrubUpdate: _handleProgressScrubUpdate,
      onScrubEnd: _resetProgressScrub,
      onScrubCancel: _resetProgressScrub,
    );
  }

  void _handleProgressScrubStart(LongPressStartDetails details, double width) {
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));
    setState(() {
      _isScrubbingProgress = true;
      _scrubStartVerse = _currentVerse;
      _scrubStartDx = details.localPosition.dx;
      _scrubStartDy = details.localPosition.dy;
      _scrubPrecision = 1.0;
    });
    _updateVerseFromProgress(
      localDx: details.localPosition.dx,
      localDy: details.localPosition.dy,
      width: width,
    );
  }

  void _handleProgressScrubUpdate(
    LongPressMoveUpdateDetails details,
    double width,
  ) {
    _updateVerseFromProgress(
      localDx: details.localPosition.dx,
      localDy: details.localPosition.dy,
      width: width,
      vibrateOnChange: true,
    );
  }

  void _resetProgressScrub() {
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
    setState(() {
      _isScrubbingProgress = false;
      _scrubStartVerse = null;
      _scrubStartDx = null;
      _scrubStartDy = null;
      _scrubPrecision = 1.0;
    });
  }

  void _setPlayerMinimized(bool minimized) {
    if (!mounted || _playerMinimized == minimized) return;
    setState(() {
      _playerMinimized = minimized;
      _playerCollapseProgress = minimized ? 1 : 0;
      _isDraggingPlayerBar = false;
    });
  }

  void _handlePlayerBarDragStart(DragStartDetails details) {
    _playerBarDragDistance = 0;
    _playerBarDragStartProgress = _playerCollapseProgress;
    _isDraggingPlayerBar = true;
  }

  void _handlePlayerBarDragUpdate(DragUpdateDetails details) {
    _playerBarDragDistance += details.primaryDelta ?? 0;
    final double width = MediaQuery.sizeOf(context).width;
    final double dragRange = width < 900 ? 110 : 96;
    setState(() {
      _playerCollapseProgress =
          (_playerBarDragStartProgress + (_playerBarDragDistance / dragRange))
              .clamp(0.0, 1.0);
    });
  }

  void _handlePlayerBarDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final double distance = _playerBarDragDistance;
    final double progress = _playerCollapseProgress;
    _playerBarDragDistance = 0;
    _isDraggingPlayerBar = false;

    if (_playerMinimized) {
      if (distance <= -_playerBarExpandDistance ||
          velocity <= -_playerBarMinVelocity ||
          progress <= 0.55) {
        _setPlayerMinimized(false);
        return;
      }

      if (distance >= _playerBarDismissDistance ||
          velocity >= _playerBarMinVelocity) {
        unawaited(_stopBottomPlayer());
        return;
      }
      setState(() {
        _playerCollapseProgress = 1;
      });
      return;
    }

    if (distance >= _playerBarMinimizeDistance ||
        velocity >= _playerBarMinVelocity ||
        progress >= 0.45) {
      _setPlayerMinimized(true);
      return;
    }

    setState(() {
      _playerCollapseProgress = 0;
    });
  }

  void _resetCardSwipeGesture() {
    _cardSwipeStartX = null;
    _cardSwipeDistance = 0;
    _cardSwipeVerticalDistance = 0;
  }

  void _handleCardSwipeStart(DragStartDetails details) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double width = mediaQuery.size.width;
    final double startX = details.localPosition.dx;
    final double leftSystemInset = mediaQuery.systemGestureInsets.left;
    final double rightSystemInset = mediaQuery.systemGestureInsets.right;
    final double leftBlockedEdge = max(
      _cardSwipeEdgeInset,
      leftSystemInset + 12,
    );
    final double rightBlockedEdge = max(
      _cardSwipeEdgeInset,
      rightSystemInset + 12,
    );
    final bool startsAtEdge =
        startX <= leftBlockedEdge || startX >= width - rightBlockedEdge;

    _cardSwipeStartX = startsAtEdge ? null : startX;
    _cardSwipeDistance = 0;
    _cardSwipeVerticalDistance = 0;
  }

  void _handleCardSwipeUpdate(DragUpdateDetails details) {
    if (_cardSwipeStartX == null) return;
    _cardSwipeDistance += details.delta.dx;
    _cardSwipeVerticalDistance += details.delta.dy.abs();
  }

  void _handleCardSwipeEnd(DragEndDetails details) {
    if (_cardSwipeStartX == null) {
      _resetCardSwipeGesture();
      return;
    }

    final double distance = _cardSwipeDistance;
    final double verticalDistance = _cardSwipeVerticalDistance;
    final double velocity = details.primaryVelocity ?? 0;
    final double minDistance = min(
      140.0,
      max(_cardSwipeMinDistance, MediaQuery.sizeOf(context).width * 0.12),
    );
    final double assistedDistance = min(
      84.0,
      max(_cardSwipeAssistDistance, minDistance * 0.56),
    );
    final double horizontalDistance = distance.abs();
    final bool isMostlyHorizontal =
        horizontalDistance >= verticalDistance * _cardSwipeAxisLockRatio;

    _resetCardSwipeGesture();

    if (!isMostlyHorizontal) return;

    final bool triggersForward =
        distance <= -minDistance ||
        (distance <= -assistedDistance && velocity <= -_cardSwipeMinVelocity);
    final bool triggersBackward =
        distance >= minDistance ||
        (distance >= assistedDistance && velocity >= _cardSwipeMinVelocity);

    if (triggersForward) {
      _increase();
    } else if (triggersBackward) {
      _decrease();
    }
  }

  Widget _buildVersePlayerBar() {
    return ReadVersePlayerBar(
      viewMode: _viewMode,
      isMounted: _playerMounted,
      isVisible: _playerVisible,
      isMinimized: _playerMinimized,
      isDragging: _isDraggingPlayerBar,
      isPlaying: _isVersePlaying,
      isLoading: _isVerseLoading,
      continuousPlayback: _continuousPlayback,
      repeatIntervalEnabled: _repeatIntervalEnabled,
      collapseProgress: _playerCollapseProgress,
      currentChapter: _currentChapter,
      currentVerse: _currentVerse,
      totalVerses: _totalVerses,
      playingVerse: _playingVerse,
      positionListenable: _playerPositionValue,
      durationListenable: _playerDurationValue,
      onHidden: _handleVersePlayerHidden,
      onExpand: () => _setPlayerMinimized(false),
      onDismiss: () => unawaited(_stopBottomPlayer()),
      onVerticalDragStart: _handlePlayerBarDragStart,
      onVerticalDragUpdate: _handlePlayerBarDragUpdate,
      onVerticalDragEnd: _handlePlayerBarDragEnd,
      onVerticalDragCancel: () => _playerBarDragDistance = 0,
      onSeek: (value) => unawaited(_seekBottomPlayer(value)),
      onTogglePlayPause: () => unawaited(_toggleBottomPlayer()),
      onContinuousPlaybackChanged: _toggleContinuousPlayback,
      onRepeatIntervalPressed: _handleRepeatIntervalPressed,
      onPlayPrevious: () => unawaited(_playAdjacentPageViewAyah(-1)),
      onPlayNext: () => unawaited(_playAdjacentPageViewAyah(1)),
    );
  }

  void _handleVersePlayerHidden() {
    if (!mounted || _playerVisible) return;
    setState(() {
      _playerMounted = false;
    });
  }

  void _handleRepeatIntervalPressed() {
    if (_repeatIntervalEnabled) {
      setState(() {
        _repeatIntervalEnabled = false;
      });
      unawaited(_updateKeepScreenOn());
      return;
    }

    unawaited(_showRepeatIntervalSheet());
  }

  double _readCardHorizontalInset(double width) {
    if (width > 1200) return 120;
    if (width > 700) return 40;
    return 6;
  }

  Widget _buildFixedPlayerBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: RepaintBoundary(child: _buildVersePlayerBar()),
    );
  }

  Widget _buildNavigationButtons({bool fixed = false}) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double width = MediaQuery.sizeOf(context).width;
    final double horizontalInset = _viewMode
        ? _readCardHorizontalInset(width)
        : (width > 700 ? 16 : 8);
    final Widget buttons = Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FilledButton.tonal(
              onPressed: () => _decrease(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                minimumSize: const Size(0, 44),
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.arrow_back_rounded, size: 22),
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _increase(),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                minimumSize: const Size(0, 44),
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.arrow_forward_rounded, size: 22),
              ),
            ),
          ],
        ),
      ),
    );

    final Widget insetButtons = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: buttons,
    );

    if (!fixed) return insetButtons;
    return Align(alignment: Alignment.bottomCenter, child: insetButtons);
  }

  Widget _buildCardViewBottomBars() {
    return RepaintBoundary(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildVersePlayerBar(),
            const SizedBox(height: 0),
            _buildNavigationButtons(fixed: true),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCurrentAyahImage() async {
    if (_isPreparingShareImage) return;

    final RenderObject? pageRenderObject = context.findRenderObject();
    final Rect? shareOrigin = pageRenderObject is RenderBox
        ? pageRenderObject.localToGlobal(Offset.zero) & pageRenderObject.size
        : null;
    String shareStep = 'preparing';

    try {
      await _pauseReadingAudioForShare();
      await _loadChapterTransliterations();
      if (!mounted) return;

      _isPreparingShareImage = true;

      shareStep = 'rendering';
      final Uint8List pngBytes = await _renderShareImagePng();
      shareStep = 'writing';
      final Directory tempDirectory = await getTemporaryDirectory();
      final File shareFile = File(
        '${tempDirectory.path}/equran_${_currentChapter}_${_currentVerse}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await shareFile.writeAsBytes(pngBytes, flush: true);

      if (!mounted) return;
      _isPreparingShareImage = false;

      shareStep = 'opening share sheet';
      await SharePlus.instance.share(
        ShareParams(
          title: 'eQuran ayah',
          subject: '${quran.getSurahName(_currentChapter)} ayah $_currentVerse',
          files: <XFile>[XFile(shareFile.path, mimeType: 'image/png')],
          sharePositionOrigin: shareOrigin,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to share ayah image while $shareStep: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'equran share image',
          context: ErrorDescription('while $shareStep'),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kDebugMode
                ? 'Unable to share ayah image while $shareStep: $error'
                : 'Unable to share ayah image.',
          ),
        ),
      );
    } finally {
      _isPreparingShareImage = false;
    }
  }

  Future<void> _pauseReadingAudioForShare() async {
    if (!_playerMounted && !_isVerseLoading) return;

    _playbackRequestId++;
    setState(() {
      _isVersePlaying = false;
      _isVerseLoading = false;
      _continuousPlayback = false;
      _repeatIntervalEnabled = false;
    });
    await _versePlayer.pause();
    await AndroidAudioDisplayMode.setAudioPlaybackActive(false);
    await _setKeepScreenOn(false);
  }

  Future<Uint8List> _renderShareImagePng() async {
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());
    final RenderView renderView = RenderView(
      view: View.of(context),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(_shareImageSize),
        physicalConstraints: BoxConstraints.tight(_shareImageSize),
        devicePixelRatio: 1,
      ),
      child: repaintBoundary,
    );

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
          container: repaintBoundary,
          child: _buildShareImageWidget(),
        ).attachToRenderTree(buildOwner);

    try {
      return _captureShareImagePng(
        repaintBoundary,
        pipelineOwner: pipelineOwner,
        buildOwner: buildOwner,
        rootElement: rootElement,
      );
    } finally {
      pipelineOwner.rootNode = null;
    }
  }

  Future<Uint8List> _captureShareImagePng(
    RenderRepaintBoundary repaintBoundary, {
    required PipelineOwner pipelineOwner,
    required BuildOwner buildOwner,
    required RenderObjectToWidgetElement<RenderBox> rootElement,
  }) async {
    Object? lastError;

    for (int attempt = 0; attempt < 12; attempt++) {
      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      try {
        final image = await repaintBoundary.toImage(pixelRatio: 1);
        try {
          final ByteData? byteData = await image.toByteData(
            format: ImageByteFormat.png,
          );
          if (byteData == null) {
            throw StateError('Unable to encode share image.');
          }
          return byteData.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }

    throw StateError('Unable to render share image: $lastError');
  }

  double _shareArabicFontSize() {
    return shareArabicFontSizeForText(
      quranVerseText(_currentChapter, _currentVerse),
    );
  }

  double _shareTranslationFontSize() {
    return shareTranslationFontSizeForText(
      quranVerseText(_currentChapter, _currentVerse),
    );
  }

  Widget _buildShareImageWidget() {
    final ThemeData theme = Theme.of(context);
    final bool showTransliteration =
        SettingsDB().get("showTransliteration", defaultValue: false) == true;
    final bool showTranslation =
        SettingsDB().get("enableTranslation", defaultValue: true) == true;
    final Color backgroundColor = theme.scaffoldBackgroundColor;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: _shareImageSize,
          devicePixelRatio: 1,
          textScaler: TextScaler.noScaling,
        ),
        child: Theme(
          data: theme,
          child: SizedBox(
            width: _shareImageSize.width,
            height: _shareImageSize.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color.alphaBlend(
                      theme.colorScheme.primary.withAlpha(18),
                      backgroundColor,
                    ),
                    backgroundColor,
                    Color.alphaBlend(
                      theme.colorScheme.tertiary.withAlpha(14),
                      backgroundColor,
                    ),
                  ],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _shareImageSize.width,
                    minWidth: _shareImageSize.width,
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: ReadQuranCard(
                      currentChapter: _currentChapter,
                      currentVerse: _currentVerse,
                      totalVerses: _totalVerses,
                      juzNumber: quran.getJuzNumber(
                        _currentChapter,
                        _currentVerse,
                      ),
                      basmala:
                          _currentChapter != 1 &&
                              _currentVerse == 1 &&
                              _currentChapter != 9
                          ? quran.basmala
                          : null,
                      verse: quranVerseText(_currentChapter, _currentVerse),
                      translation: quran.getVerseTranslation(
                        _currentChapter,
                        _currentVerse,
                        translation:
                            quran.Translation.values[SettingsDB().get(
                              "translation",
                              defaultValue: 0,
                            )],
                      ),
                      transliteration: _transliterationForVerse(_currentVerse),
                      showActions: false,
                      showTransliteration: showTransliteration,
                      showTranslation: showTranslation,
                      shareImageMode: true,
                      fontSize: _shareArabicFontSize(),
                      fontSizeTranslation: _shareTranslationFontSize(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget cardView({required double marginValue}) {
    final bool compactPlayerLayout = MediaQuery.sizeOf(context).width < 700;
    final double expandedSpacer = compactPlayerLayout ? 392 : 304;
    final double bottomSpacer = _playerMounted
        ? lerpDouble(expandedSpacer, 132, _playerCollapseProgress)!
        : 180;

    return SafeArea(
      child: GestureDetector(
        onHorizontalDragStart: _handleCardSwipeStart,
        onHorizontalDragUpdate: _handleCardSwipeUpdate,
        onHorizontalDragEnd: _handleCardSwipeEnd,
        onHorizontalDragCancel: _resetCardSwipeGesture,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _notifyAudioUserActivity();
                return false;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildProgressBar(marginValue),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: RepaintBoundary(
                        child: ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: ReadQuranCard(
                            currentChapter: _currentChapter,
                            currentVerse: _currentVerse,
                            totalVerses: _totalVerses,
                            juzNumber: quran.getJuzNumber(
                              _currentChapter,
                              _currentVerse,
                            ),
                            basmala:
                                _currentChapter != 1 &&
                                    _currentVerse == 1 &&
                                    _currentChapter != 9
                                ? quran.basmala
                                : null,
                            verse: quranVerseText(
                              _currentChapter,
                              _currentVerse,
                            ),
                            translation: quran.getVerseTranslation(
                              _currentChapter,
                              _currentVerse,
                              translation:
                                  quran.Translation.values[SettingsDB().get(
                                    "translation",
                                    defaultValue: 0,
                                  )],
                            ),
                            transliteration: _cardTransliterationForVerse(
                              _currentVerse,
                            ),
                            showTransliteration:
                                SettingsDB().get(
                                  "showTransliteration",
                                  defaultValue: false,
                                ) ==
                                true,
                            showTranslation:
                                SettingsDB().get(
                                  "enableTranslation",
                                  defaultValue: true,
                                ) ==
                                true,
                            fontSize: SettingsDB().get(
                              "fontSize",
                              defaultValue: 31.0,
                            ),
                            fontSizeTranslation: SettingsDB().get(
                              "fontSizeTranslation",
                              defaultValue: 12.0,
                            ),
                            onPlay: _togglePageViewPlayback,
                            onDownload: _downloadCurrentAyah,
                            onDeleteDownload: _confirmDeleteCurrentAyahDownload,
                            onShare: _shareCurrentAyahImage,
                            onSwitchTranslation:
                                _showCardTranslationLanguagePicker,
                            onTafsir: () => _showTafsirSheet(_currentVerse),
                            onPrevious: _currentVerse > 1
                                ? () {
                                    _setVerse(_currentVerse - 1);
                                    _scrollUp();
                                    _updateDB();
                                  }
                                : null,
                            onNext: _currentVerse < _totalVerses
                                ? () {
                                    _setVerse(_currentVerse + 1);
                                    _scrollUp();
                                    _updateDB();
                                  }
                                : null,
                            isPlaying:
                                _isVersePlaying &&
                                _playingVerse == _currentVerse,
                            isDownloading: _downloadingAyahKeys.contains(
                              '$_currentChapter-$_currentVerse',
                            ),
                            isDownloaded: _hasDownloadedCurrentAyah,
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      height: bottomSpacer,
                    ),
                  ],
                ),
              ),
            ),
            _buildCardViewBottomBars(),
          ],
        ),
      ),
    );
  }

  Widget listView({required double marginValue}) {
    final double fontSize = SettingsDB().get("fontSize", defaultValue: 31.0);
    final double pageMargin = marginValue > 8 ? 16 : 8;
    final bool compactPlayerLayout = MediaQuery.sizeOf(context).width < 700;
    final double playerBottomPadding = lerpDouble(
      compactPlayerLayout ? 260 : 190,
      76,
      _playerCollapseProgress,
    )!;

    return SafeArea(
      key: _pageViewViewportKey,
      child: Stack(
        children: <Widget>[
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _notifyAudioUserActivity();
              if (notification is ScrollEndNotification) {
                _syncPageProgressFromScroll();
              } else if (notification is UserScrollNotification &&
                  notification.direction == ScrollDirection.idle) {
                _syncPageProgressFromScroll();
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: 2,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: _playerMounted ? playerBottomPadding : 24,
              ),
              itemBuilder: (context, index) {
                if (index == 1) {
                  return _buildNavigationButtons();
                }

                return _buildPageViewSurahCard(
                  fontSize: fontSize,
                  pageMargin: pageMargin,
                );
              },
            ),
          ),
          _buildFixedPlayerBar(),
        ],
      ),
    );
  }

  Widget _buildPageViewSurahCard({
    required double fontSize,
    required double pageMargin,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color pageCardColor =
        theme.cardTheme.color ?? colorScheme.surfaceContainerLow;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pageMargin, vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pageCardColor,
          borderRadius: BorderRadius.circular(AppRadii.small),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha((0.45 * 255).round()),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_currentChapter != 1 && _currentChapter != 9)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    quran.basmala,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 2,
                      fontFamily: 'Hafs',
                      fontSize: fontSize,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildInlineSurahText(fontSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineSurahText(double fontSize) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: _handleInlineSurahLongPressStart,
      child: RichText(
        key: _inlineSurahTextKey,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
        text: _buildInlineSurahTextSpan(fontSize, colorScheme),
      ),
    );
  }

  TextSpan _buildInlineSurahTextSpan(double fontSize, ColorScheme colorScheme) {
    final TextStyle baseStyle = TextStyle(
      fontFamily: 'Hafs',
      height: 1.8,
      fontSize: fontSize,
      color: colorScheme.onSurface,
    );
    final String surahText = _inlineSurahText();
    final int? highlightedVerse = _selectedInlineVerse ?? _playingVerse;

    if (highlightedVerse == null ||
        highlightedVerse < 1 ||
        highlightedVerse > _totalVerses) {
      return TextSpan(text: surahText, style: baseStyle);
    }

    _ensureVerseTextMetrics();
    final List<int> lengths = _verseTextCumulativeLengths ?? <int>[0];
    if (lengths.length <= highlightedVerse) {
      return TextSpan(text: surahText, style: baseStyle);
    }

    final int start = lengths[highlightedVerse - 1];
    final int end = lengths[highlightedVerse]
        .clamp(start, surahText.length)
        .toInt();
    final TextStyle highlightStyle = baseStyle.copyWith(
      color: colorScheme.primary,
    );

    return TextSpan(
      style: baseStyle,
      children: <InlineSpan>[
        if (start > 0) TextSpan(text: surahText.substring(0, start)),
        TextSpan(text: surahText.substring(start, end), style: highlightStyle),
        if (end < surahText.length) TextSpan(text: surahText.substring(end)),
      ],
    );
  }

  void _handleInlineSurahLongPressStart(LongPressStartDetails details) {
    final RenderObject? renderObject = _inlineSurahTextKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderParagraph) return;

    final Offset localPosition = renderObject.globalToLocal(
      details.globalPosition,
    );
    final TextPosition textPosition = renderObject.getPositionForOffset(
      localPosition,
    );
    final int verse = _verseForTextOffset(textPosition.offset);
    _showAyahActions(verse);
  }

  Future<void> _showAyahActions(int verse) async {
    _inlineVerseHighlightTimer?.cancel();
    setState(() {
      _selectedInlineVerse = verse;
      _currentVerse = verse;
    });
    _updateDB();

    await _withLowFpsSuppressed(() {
      return showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          bool isFavourite = FavouritesDB().contains(
            favouriteAyahKey(_currentChapter, verse),
          );
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      title: Text(
                        '${quran.getSurahName(_currentChapter)} • Ayah $verse',
                      ),
                      subtitle: const Text('Choose an action'),
                      trailing: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: LikeButton(
                            size: 28,
                            isLiked: isFavourite,
                            circleColor: CircleColor(
                              start: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(180),
                              end: Theme.of(context).colorScheme.primary,
                            ),
                            bubblesColor: BubblesColor(
                              dotPrimaryColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              dotSecondaryColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                            ),
                            likeBuilder: (bool liked) {
                              return Icon(
                                liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: liked
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                size: 28,
                              );
                            },
                            onTap: (bool liked) async {
                              if (liked) {
                                _toggleFavourite(verse, isFavourite: true);
                                if (!mounted) return false;

                                setSheetState(() {
                                  isFavourite = false;
                                });

                                return false;
                              }

                              await _showFavouriteNotePrompt(verse);
                              if (!mounted) return liked;

                              setSheetState(() {
                                isFavourite = true;
                              });

                              return true;
                            },
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline_rounded),
                      title: const Text('Play this ayah'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _playVerse(_currentChapter, verse, continuous: false);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.ios_share_outlined),
                      title: const Text('Share image'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _shareCurrentAyahImage();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.chrome_reader_mode_rounded),
                      title: const Text('Show tafsir'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _showTafsirSheet(verse);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.notes_rounded),
                      title: const Text('Ayah details'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _showAyahDetailsSheet(verse);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    });
    if (!mounted) return;
    setState(() {
      _selectedInlineVerse = null;
    });
  }

  Future<void> _showAyahDetailsSheet(int verse) async {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String transliteration = _transliterationForVerse(verse).trim();
    final String translation = quran.getVerseTranslation(
      _currentChapter,
      verse,
      translation: quran.Translation.values[_selectedTranslationIndex()],
    );

    await _withLowFpsSuppressed(() {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.52,
            minChildSize: 0.36,
            maxChildSize: 0.86,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: <Widget>[
                  Text(
                    '${quran.getSurahName(_currentChapter)} • Ayah $verse',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    quranVerseText(_currentChapter, verse),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontFamily: 'Hafs',
                      fontSize: SettingsDB().get(
                        "fontSize",
                        defaultValue: 31.0,
                      ),
                      height: 1.7,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  ...<Widget>[
                    const SizedBox(height: 18),
                    Text(
                      transliteration,
                      textAlign: TextAlign.justify,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    translation,
                    textAlign: TextAlign.justify,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.55,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  Future<int?> _showTranslationPickerDialog(int selectedTranslation) {
    return showDialog<int>(
      context: context,
      builder: (context) => AppSelectionDialog<int>(
        title: 'Translation Language',
        icon: Icons.translate_rounded,
        selectedValue: selectedTranslation,
        maxWidth: 420,
        maxHeight: 520,
        options:
            quran.Translation.values
                .asMap()
                .entries
                .map(
                  (entry) => AppSelectionOption<int>(
                    value: entry.key,
                    title: translationDisplayName(entry.value),
                  ),
                )
                .toList()
              ..sort((a, b) => a.title.compareTo(b.title)),
      ),
    );
  }

  void _showCardTranslationLanguagePicker() {
    unawaited(_openCardTranslationLanguagePicker());
  }

  Future<void> _openCardTranslationLanguagePicker() async {
    final int? value = await _showTranslationPickerDialog(
      _selectedTranslationIndex(),
    );
    if (value == null || !mounted) return;
    SettingsDB().put("translation", value);
    setState(() {});
  }

  int _selectedTranslationIndex() {
    final dynamic savedTranslation = SettingsDB().get(
      "translation",
      defaultValue: 0,
    );
    if (savedTranslation is int &&
        savedTranslation >= 0 &&
        savedTranslation < quran.Translation.values.length) {
      return savedTranslation;
    }
    return 0;
  }

  Future<void> _showTafsirSheet(int verse) async {
    const TafsirSource selectedSource = TafsirSource.mukhtasar;
    final Future<String> tafsirFuture = TafsirService.instance.verseTafsir(
      source: selectedSource,
      surah: _currentChapter,
      ayah: verse,
    );

    await _withLowFpsSuppressed(() {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
        builder: (context) {
          return FutureBuilder<String>(
            future: tafsirFuture,
            builder: (context, tafsirSnapshot) {
              final String tafsirText = tafsirSnapshot.data?.trim() ?? '';
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.56,
                minChildSize: 0.28,
                maxChildSize: 0.92,
                builder: (context, scrollController) {
                  return SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${quran.getSurahName(_currentChapter)} • Ayah $verse',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedSource.displayName,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child:
                                tafsirSnapshot.connectionState !=
                                    ConnectionState.done
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : SingleChildScrollView(
                                    controller: scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    child: Text(
                                      tafsirText.isEmpty
                                          ? 'No tafsir text available for this ayah.'
                                          : tafsirText,
                                      textAlign: TextAlign.start,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(height: 1.6),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    });
  }

  Future<void> _showFavouriteNotePrompt(int verse) async {
    final TextEditingController textController = TextEditingController();
    try {
      await _withLowFpsSuppressed(() {
        return showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Favourite ayah'),
              content: TextField(
                maxLength: 80,
                maxLines: null,
                controller: textController,
                decoration: const InputDecoration(hintText: 'Optional note...'),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () {
                    final String key = favouriteAyahKey(_currentChapter, verse);
                    FavouritesDB().put(key, textController.text.trim());
                    Navigator.of(context).pop();
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      });
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      textController.dispose();
    }
  }

  void _toggleFavourite(int verse, {required bool isFavourite}) {
    final String key = favouriteAyahKey(_currentChapter, verse);
    if (isFavourite) {
      FavouritesDB().delete(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favourites.')),
        );
      }
      return;
    }
    FavouritesDB().put(key, '');
  }
}
