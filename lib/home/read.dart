import 'dart:async';
import 'dart:ui' show ImageFilter, TextBox;
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:equran/backend/bookmark_db.dart';
import 'package:equran/backend/library.dart'
    show
        AndroidAudioDisplayMode,
        AudioDownloadService,
        DownloadNotifications,
        FavouritesDB,
        QuranAudioService,
        SettingsDB;
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:equran/widgets/library.dart' show ReadQuranCard;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph, ScrollDirection;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:numberpicker/numberpicker.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:quran/quran.dart' as quran;
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
  bool _isVersePlaying = false;
  bool _isVerseLoading = false;
  bool _isDownloadingSurahAyahs = false;
  bool _hasDownloadedSurahAyahs = false;
  bool _continuousPlayback = false;
  bool _repeatIntervalEnabled = false;
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
  int? _scrubStartVerse;
  double? _scrubStartDx;
  double? _scrubStartDy;
  double _scrubPrecision = 1.0;

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
    _pageFocusNode = FocusNode(debugLabel: 'Read Page Keyboard Focus');
    _getTotalVerses();
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
    return '\u2067${_buildVerseText(_currentChapter, verse)}\u2069  ';
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
                    ),
                  ),
                if (!_viewMode)
                  IconButton(
                    tooltip: _hasDownloadedSurahAyahs
                        ? 'All ayahs downloaded'
                        : 'Download all ayahs',
                    onPressed: _isDownloadingSurahAyahs
                        ? null
                        : _downloadCurrentSurahAyahs,
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
                          ),
                  ),
                if (_viewMode)
                  IconButton(
                    tooltip: 'Reset',
                    onPressed: () => _showResetDialog(context),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                IconButton(
                  tooltip: 'Jump to verse',
                  onPressed: () => _showJumpToVerseDialog(context),
                  icon: const Icon(Icons.format_list_numbered_rounded),
                ),
                const SizedBox(width: 6),
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

  Future<void> _showResetDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.warning_amber),
        title: const Text('Reset'),
        content: const Text('Would you like to start over?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              _reset();
              _updateDB();
              if (!SettingsDB().get("viewMode", defaultValue: true)) {
                _scrollUp();
              }
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJumpToVerseDialog(BuildContext context) async {
    if (!_viewMode) {
      _syncCurrentVerseWithVisibleText(persist: true);
    }

    int picker = _currentVerse;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Select Verse'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              _setVerse(picker);
              if (!_viewMode) {
                _scrollToInlineVerse(picker, highlight: true);
              }
              _updateDB();
              Navigator.of(context).pop();
            },
            child: const Text('CONFIRM'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
        ],
        content: StatefulBuilder(
          builder: (context, sBsetState) => NumberPicker(
            minValue: 1,
            maxValue: _totalVerses,
            value: picker,
            onChanged: (int value) {
              setState(() => picker = value);
              sBsetState(() => picker = value);
            },
          ),
        ),
      ),
    );
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
      !_viewMode &&
          _playerVisible &&
          (_continuousPlayback || _repeatIntervalEnabled),
    );
  }

  Future<void> _playVerse(
    int surah,
    int verse, {
    bool continuous = false,
    bool smoothScroll = false,
  }) async {
    if (_isVerseLoading) return;

    final int requestId = ++_playbackRequestId;
    setState(() {
      _playerVisible = true;
      _playerMounted = true;
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
      await _versePlayer.play(UrlSource(url));
    }
    await _versePlayer.setPlaybackRate(rate);
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
      await _playVerse(_currentChapter, nextVerse, smoothScroll: true);
      return;
    }

    if (_continuousPlayback && completedVerse < _totalVerses) {
      await _playVerse(
        _currentChapter,
        completedVerse + 1,
        continuous: true,
        smoothScroll: true,
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
    if (_viewMode || _isVerseLoading) return;

    final int currentVerse = _playingVerse ?? _currentVerse;
    final int targetVerse = currentVerse + direction;
    if (targetVerse < 1 || targetVerse > _totalVerses) return;

    await _playVerse(
      _currentChapter,
      targetVerse,
      continuous: _continuousPlayback,
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

    unawaited(_playVerse(_currentChapter, _currentVerse, continuous: true));
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
      _playingVerse ??= _currentVerse;
      if (value) {
        _repeatStartVerse = _currentVerse;
        _repeatEndVerse = _currentVerse;
      }
    });
    unawaited(_updateKeepScreenOn());
  }

  Future<void> _showRepeatIntervalSheet() async {
    int start = _repeatIntervalEnabled ? _repeatStartVerse : _currentVerse;
    int end = _repeatIntervalEnabled ? _repeatEndVerse : _currentVerse;

    final bool? enabled = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Repeat Ayah Interval',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Disable'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Repeat Interval'),
                          ),
                        ),
                      ],
                    ),
                  ],
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

    setState(() {
      _repeatIntervalEnabled = true;
      _continuousPlayback = false;
      _playerVisible = true;
      _playerMounted = true;
      _repeatStartVerse = start;
      _repeatEndVerse = end;
      _playingVerse = start;
    });
    unawaited(_updateKeepScreenOn());
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
    _updateDB();
  }

  void _goToPreviousSurah() {
    if (_playerMounted || _playingVerse != null) {
      unawaited(_stopBottomPlayer());
    }
    _clearVerseTextMetrics();
    setState(() {
      _currentChapter = _currentChapter == 1 ? 114 : _currentChapter - 1;
      _currentVerse = 1;
      _totalVerses = quran.getVerseCount(_currentChapter);
      _repeatStartVerse = 1;
      _repeatEndVerse = 1;
      _isDownloadingSurahAyahs = AudioDownloadService()
          .isSurahAyahsDownloadInProgress(_currentChapter);
      _hasDownloadedSurahAyahs = false;
    });
    unawaited(_refreshSurahAyahDownloadState());
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
  }

  void _resetChapter() {
    _clearVerseTextMetrics();
    setState(() {
      _currentChapter = 1;
    });
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
    final int progressVerse = _isScrubbingProgress
        ? (_scrubStartVerse ?? _currentVerse)
        : _currentVerse;
    final double percent = _totalVerses <= 1
        ? 1
        : ((progressVerse - 1) / (_totalVerses - 1)).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.only(left: marginValue, right: marginValue, top: 20),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double scrubPercent = _totalVerses <= 1
              ? 1
              : ((_currentVerse - 1) / (_totalVerses - 1)).clamp(0.0, 1.0);
          final double indicatorSize = 16;
          final double indicatorLeft =
              (scrubPercent * constraints.maxWidth - (indicatorSize / 2))
                  .clamp(0.0, constraints.maxWidth - indicatorSize)
                  .toDouble();

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (details) {
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
                width: constraints.maxWidth,
              );
            },
            onLongPressMoveUpdate: (details) {
              _updateVerseFromProgress(
                localDx: details.localPosition.dx,
                localDy: details.localPosition.dy,
                width: constraints.maxWidth,
                vibrateOnChange: true,
              );
            },
            onLongPressEnd: (_) {
              setState(() {
                _isScrubbingProgress = false;
                _scrubStartVerse = null;
                _scrubStartDx = null;
                _scrubStartDy = null;
                _scrubPrecision = 1.0;
              });
            },
            onLongPressCancel: () {
              setState(() {
                _isScrubbingProgress = false;
                _scrubStartVerse = null;
                _scrubStartDx = null;
                _scrubStartDy = null;
                _scrubPrecision = 1.0;
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: <Widget>[
                LinearPercentIndicator(
                  barRadius: const Radius.circular(30),
                  animation: !_isScrubbingProgress,
                  animateFromLastPercent: !_isScrubbingProgress,
                  backgroundColor: Theme.of(context).colorScheme.onTertiary,
                  lineHeight: 20.0,
                  percent: percent,
                  progressColor: Theme.of(context).colorScheme.tertiary,
                ),
                if (_isScrubbingProgress)
                  Positioned(
                    left: indicatorLeft,
                    child: IgnorePointer(
                      child: Container(
                        width: indicatorSize,
                        height: indicatorSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final String minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildVersePlayerBar() {
    if (!_playerMounted) return const SizedBox.shrink();

    final double width = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        final double velocity = details.primaryVelocity ?? 0;
        if (velocity > 220) {
          _stopBottomPlayer();
        }
      },
      child: AnimatedSlide(
        offset: _playerVisible ? Offset.zero : const Offset(0, 1.15),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        onEnd: () {
          if (!mounted || _playerVisible) return;
          setState(() {
            _playerMounted = false;
          });
        },
        child: AnimatedOpacity(
          opacity: _playerVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: ValueListenableBuilder<Duration>(
            valueListenable: _playerPositionValue,
            builder: (context, position, _) {
              return ValueListenableBuilder<Duration>(
                valueListenable: _playerDurationValue,
                builder: (context, duration, _) {
                  return width < 900
                      ? _buildCompactVersePlayerBar(
                          position: position,
                          duration: duration,
                        )
                      : _buildWidescreenVersePlayerBar(
                          width,
                          position: position,
                          duration: duration,
                        );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactVersePlayerBar({
    required Duration position,
    required Duration duration,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double progress = duration.inMilliseconds <= 0
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: _buildFrostedPlayerSurface(
        colorScheme: colorScheme,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: SafeArea(
          top: false,
          child: Stack(
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: Slider(
                      value: progress,
                      onChanged: duration.inMilliseconds <= 0
                          ? null
                          : _seekBottomPlayer,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _formatDuration(position),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _buildAutoPlaybackButton(colorScheme),
                      if (!_viewMode) ...<Widget>[
                        const SizedBox(width: 8),
                        _buildPageViewAyahNavButton(
                          icon: Icons.skip_previous_rounded,
                          tooltip: 'Previous ayah',
                          onPressed: (_playingVerse ?? _currentVerse) <= 1
                              ? null
                              : () => unawaited(_playAdjacentPageViewAyah(-1)),
                        ),
                      ],
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _toggleBottomPlayer,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(18),
                        ),
                        child: _isVerseLoading
                            ? SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Icon(
                                _isVersePlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 32,
                              ),
                      ),
                      if (!_viewMode) ...<Widget>[
                        const SizedBox(width: 8),
                        _buildPageViewAyahNavButton(
                          icon: Icons.skip_next_rounded,
                          tooltip: 'Next ayah',
                          onPressed:
                              (_playingVerse ?? _currentVerse) >= _totalVerses
                              ? null
                              : () => unawaited(_playAdjacentPageViewAyah(1)),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _buildRepeatIntervalButton(colorScheme),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: -8,
                right: -8,
                child: IconButton(
                  tooltip: 'Dismiss player',
                  onPressed: _stopBottomPlayer,
                  icon: const Icon(Icons.close_rounded),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidescreenVersePlayerBar(
    double width, {
    required Duration position,
    required Duration duration,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double progress = duration.inMilliseconds <= 0
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    final bool isCompactWidescreenLayout = width < 1100;
    final double centerGap = isCompactWidescreenLayout ? 96 : 220;
    final double centerWidth = min(
      isCompactWidescreenLayout ? 300.0 : 640.0,
      max(isCompactWidescreenLayout ? 280.0 : 320.0, width - 760),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: _buildFrostedPlayerSurface(
        colorScheme: colorScheme,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: width >= 1500 ? 132 : 124),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Expanded(child: SizedBox.shrink()),
                    SizedBox(width: centerGap),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Dismiss player',
                              onPressed: _stopBottomPlayer,
                              icon: const Icon(Icons.close_rounded, size: 28),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  ignoring: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: centerWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _buildAutoPlaybackButton(colorScheme),
                              if (!_viewMode)
                                _buildPageViewAyahNavButton(
                                  icon: Icons.skip_previous_rounded,
                                  tooltip: 'Previous ayah',
                                  onPressed:
                                      (_playingVerse ?? _currentVerse) <= 1
                                      ? null
                                      : () => unawaited(
                                          _playAdjacentPageViewAyah(-1),
                                        ),
                                ),
                              FilledButton(
                                onPressed: _toggleBottomPlayer,
                                style: FilledButton.styleFrom(
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(18),
                                ),
                                child: _isVerseLoading
                                    ? SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: colorScheme.onPrimary,
                                        ),
                                      )
                                    : Icon(
                                        _isVersePlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 32,
                                      ),
                              ),
                              if (!_viewMode)
                                _buildPageViewAyahNavButton(
                                  icon: Icons.skip_next_rounded,
                                  tooltip: 'Next ayah',
                                  onPressed:
                                      (_playingVerse ?? _currentVerse) >=
                                          _totalVerses
                                      ? null
                                      : () => unawaited(
                                          _playAdjacentPageViewAyah(1),
                                        ),
                                ),
                              _buildRepeatIntervalButton(colorScheme),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              SizedBox(
                                width: 64,
                                child: Text(
                                  _formatDuration(position),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: progress,
                                  onChanged: duration.inMilliseconds <= 0
                                      ? null
                                      : _seekBottomPlayer,
                                ),
                              ),
                              SizedBox(
                                width: 64,
                                child: Text(
                                  _formatDuration(duration),
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _readPlayerDecoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.surface.withAlpha((0.72 * 255).round()),
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: Border.all(
        color: colorScheme.outlineVariant.withAlpha((0.4 * 255).round()),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: colorScheme.shadow.withAlpha((0.18 * 255).round()),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _buildFrostedPlayerSurface({
    required ColorScheme colorScheme,
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: _readPlayerDecoration(colorScheme),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAutoPlaybackButton(ColorScheme colorScheme) {
    final bool isActive = _continuousPlayback && !_repeatIntervalEnabled;

    return IconButton(
      tooltip: 'Auto Playback',
      onPressed: () => _toggleContinuousPlayback(!isActive),
      icon: const Icon(Icons.playlist_play_rounded),
      color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        side: isActive
            ? BorderSide(color: colorScheme.primary, width: 1.8)
            : BorderSide.none,
      ),
    );
  }

  Widget _buildPageViewAyahNavButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 30,
    );
  }

  Widget _buildRepeatIntervalButton(
    ColorScheme colorScheme, {
    IconData icon = Icons.all_inclusive_rounded,
    double? iconSize,
  }) {
    return IconButton(
      tooltip: 'Repeat Interval',
      onPressed: _showRepeatIntervalSheet,
      icon: Icon(icon, size: iconSize),
      color: _repeatIntervalEnabled
          ? colorScheme.primary
          : colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        side: _repeatIntervalEnabled
            ? BorderSide(color: colorScheme.primary, width: 1.8)
            : BorderSide.none,
      ),
    );
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
    final Widget buttons = Container(
      height: 80,
      padding: const EdgeInsets.only(right: 12, left: 12),
      color: fixed ? Theme.of(context).colorScheme.surface : Colors.transparent,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: () => _decrease(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 18),
                child: Icon(Icons.arrow_back_rounded, size: 30),
              ),
            ),
            ElevatedButton(
              onPressed: () => _increase(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 18),
                child: Icon(Icons.arrow_forward_rounded, size: 30),
              ),
            ),
          ],
        ),
      ),
    );

    if (!fixed) return buttons;
    return Align(alignment: Alignment.bottomCenter, child: buttons);
  }

  Widget _buildCardViewBottomBars() {
    return RepaintBoundary(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildVersePlayerBar(),
            _buildNavigationButtons(fixed: true),
          ],
        ),
      ),
    );
  }

  Widget cardView({required double marginValue}) {
    final bool compactPlayerLayout = MediaQuery.sizeOf(context).width < 700;
    final double bottomSpacer = _playerMounted
        ? (compactPlayerLayout ? 360 : 280)
        : 180;

    return SafeArea(
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final double velocity = details.primaryVelocity ?? 0;
          if (velocity < -200) {
            _increase();
          } else if (velocity > 200) {
            _decrease();
          }
        },
        child: Stack(
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
                        verse: _buildCardVerseText(
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
                        url: QuranAudioService().getAyahUrl(
                          _currentChapter,
                          _currentVerse,
                        ),
                        fontSize: SettingsDB().get(
                          "fontSize",
                          defaultValue: 38.0,
                        ),
                        fontSizeTranslation: SettingsDB().get(
                          "fontSizeTranslation",
                          defaultValue: 18.0,
                        ),
                        onPlayRequested: (surah, ayah) => _playVerse(
                          surah,
                          ayah,
                          continuous: _continuousPlayback,
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
    final double fontSize = SettingsDB().get("fontSize", defaultValue: 38.0);
    final double pageMargin = marginValue > 8 ? 16 : 8;
    final bool compactPlayerLayout = MediaQuery.sizeOf(context).width < 700;
    final double playerBottomPadding = compactPlayerLayout ? 260 : 190;

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

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final String key = _favouriteKey(_currentChapter, verse);
        final bool isFavourite = FavouritesDB().contains(key);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text(
                  '${quran.getSurahName(_currentChapter)} • Ayah $verse',
                ),
                subtitle: const Text('Choose an action'),
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
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Show translation'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showTranslationSheet(verse);
                },
              ),
              ListTile(
                leading: Icon(
                  isFavourite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                title: Text(isFavourite ? 'Remove favourite' : 'Favourite'),
                onTap: () {
                  Navigator.of(context).pop();
                  _toggleFavourite(verse, isFavourite: isFavourite);
                },
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _selectedInlineVerse = null;
    });
  }

  Future<void> _showTranslationSheet(int verse) async {
    final String translation = quran.getVerseTranslation(
      _currentChapter,
      verse,
      translation: quran
          .Translation
          .values[SettingsDB().get("translation", defaultValue: 0)],
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${quran.getSurahName(_currentChapter)} • Ayah $verse',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(translation, textAlign: TextAlign.justify),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleFavourite(int verse, {required bool isFavourite}) {
    final String key = _favouriteKey(_currentChapter, verse);
    if (isFavourite) {
      FavouritesDB().delete(key);
      return;
    }
    FavouritesDB().put(key, '');
  }

  String _favouriteKey(int chapter, int verse) {
    return "$chapter-${verse.toString().padLeft(3, "0")}";
  }

  String _buildVerseText(int chapter, int verse) {
    final verseText =
        '${quran.getVerse(chapter, verse)} ${_arabicVerseNumber(verse)}';
    if (verse == 1 && chapter != 1) {
      return verseText.replaceAll(
        "بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ",
        "",
      );
    }
    return verseText;
  }

  String _buildCardVerseText(int chapter, int verse) {
    final verseText = quran.getVerse(chapter, verse);
    if (verse == 1 && chapter != 1) {
      return verseText.replaceAll(
        "بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ",
        "",
      );
    }
    return verseText;
  }

  String _arabicVerseNumber(int verse) {
    const Map<String, String> arabicDigits = <String, String>{
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };

    return verse
        .toString()
        .split('')
        .map((digit) => arabicDigits[digit] ?? digit)
        .join();
  }
}
