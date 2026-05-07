import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show DisplayFeature, DisplayFeatureType, ImageFilter;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:equran/backend/library.dart'
    show
        AndroidAudioDisplayMode,
        AudioDownloadService,
        DownloadNotifications,
        QuranAudioService,
        QuranTransliterationService,
        SurahTiming,
        SurahTimingRepository,
        SettingsDB;
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/app_slider_theme.dart';
import 'package:equran/utils/number_formatting.dart';
import 'package:equran/utils/quran_text.dart';
import 'package:equran/utils/reciter.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:equran/widgets/app_selection_dialog.dart';
import 'package:equran/widgets/read_quran_card.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:quran/quran.dart' as quran;

const List<String> _surahTransliterations = <String>[
  'Al-Fatihah',
  'Al-Baqarah',
  "Ali 'Imran",
  'An-Nisa',
  "Al-Ma'idah",
  "Al-An'am",
  "Al-A'raf",
  'Al-Anfal',
  'At-Tawbah',
  'Yunus',
  'Hud',
  'Yusuf',
  "Ar-Ra'd",
  'Ibrahim',
  'Al-Hijr',
  'An-Nahl',
  'Al-Isra',
  'Al-Kahf',
  'Maryam',
  'Ta-Ha',
  'Al-Anbiya',
  'Al-Hajj',
  "Al-Mu'minun",
  'An-Nur',
  'Al-Furqan',
  "Ash-Shu'ara",
  'An-Naml',
  'Al-Qasas',
  'Al-Ankabut',
  'Ar-Rum',
  'Luqman',
  'As-Sajdah',
  'Al-Ahzab',
  'Saba',
  'Fatir',
  'Ya-Sin',
  'As-Saffat',
  'Sad',
  'Az-Zumar',
  'Ghafir',
  'Fussilat',
  'Ash-Shura',
  'Az-Zukhruf',
  'Ad-Dukhan',
  'Al-Jathiyah',
  'Al-Ahqaf',
  'Muhammad',
  'Al-Fath',
  'Al-Hujurat',
  'Qaf',
  'Adh-Dhariyat',
  'At-Tur',
  'An-Najm',
  'Al-Qamar',
  'Ar-Rahman',
  "Al-Waqi'ah",
  'Al-Hadid',
  'Al-Mujadilah',
  'Al-Hashr',
  'Al-Mumtahanah',
  'As-Saff',
  "Al-Jumu'ah",
  'Al-Munafiqun',
  'At-Taghabun',
  'At-Talaq',
  'At-Tahrim',
  'Al-Mulk',
  'Al-Qalam',
  'Al-Haqqah',
  "Al-Ma'arij",
  'Nuh',
  'Al-Jinn',
  'Al-Muzzammil',
  'Al-Muddaththir',
  'Al-Qiyamah',
  'Al-Insan',
  'Al-Mursalat',
  'An-Naba',
  "An-Nazi'at",
  'Abasa',
  'At-Takwir',
  'Al-Infitar',
  'Al-Mutaffifin',
  'Al-Inshiqaq',
  'Al-Buruj',
  'At-Tariq',
  "Al-A'la",
  'Al-Ghashiyah',
  'Al-Fajr',
  'Al-Balad',
  'Ash-Shams',
  'Al-Layl',
  'Ad-Duha',
  'Ash-Sharh',
  'At-Tin',
  'Al-Alaq',
  'Al-Qadr',
  'Al-Bayyinah',
  'Az-Zalzalah',
  'Al-Adiyat',
  "Al-Qari'ah",
  'At-Takathur',
  'Al-Asr',
  'Al-Humazah',
  'Al-Fil',
  'Quraysh',
  "Al-Ma'un",
  'Al-Kawthar',
  'Al-Kafirun',
  'An-Nasr',
  'Al-Masad',
  'Al-Ikhlas',
  'Al-Falaq',
  'An-Nas',
];

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static const double _playerPageAudioFrameRate = 24.0;

  final ja.AudioPlayer _justAudio = ja.AudioPlayer();
  final ap.AudioPlayer _fallbackAudio = ap.AudioPlayer();
  final AudioDownloadService _downloads = AudioDownloadService();
  final SurahTimingRepository _timingRepository = SurahTimingRepository();
  final Random _random = Random();

  late final bool _useAudioplayersFallback;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<ja.PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _fallbackPositionSubscription;
  StreamSubscription<Duration>? _fallbackDurationSubscription;
  StreamSubscription<ap.PlayerState>? _fallbackStateSubscription;
  StreamSubscription<void>? _fallbackCompleteSubscription;

  int _selectedSurah = 1;
  int? _loadedSurah;
  bool? _loadedFromOffline;
  String? _loadedReciterCode;

  bool _isLoading = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isTimingLoading = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _playingFromOffline = false;
  bool _shuffleEnabled = false;
  bool _loopEnabled = false;
  bool _isCompletingTrack = false;
  bool _showProgressThumb = false;
  bool _isScrubbing = false;
  int _progressVisualBlockCount = 0;
  int _timingLoadGeneration = 0;
  int? _activeAyah;
  int? _timingSurah;
  int? _transliterationSurah;
  double? _pendingSeekProgress;
  Duration? _scrubPreviewPosition;
  String? _timingReciterCode;
  bool? _selectionTimingSupported;
  SurahTiming? _surahTiming;
  List<String> _surahTransliterationsCache = const <String>[];

  double _playbackRate = 1.0;
  Duration _position = Duration.zero;
  Duration _displayedPosition = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _progressThumbTimer;

  @override
  void initState() {
    super.initState();
    unawaited(
      AndroidAudioDisplayMode.setLimitedProgressFrameRate(
        _playerPageAudioFrameRate,
      ),
    );

    _useAudioplayersFallback =
        !kIsWeb && (Platform.isLinux || Platform.isWindows);

    final dynamic rate = SettingsDB().get("playbackRate", defaultValue: 1.0);
    if (rate is num) {
      _playbackRate = rate.toDouble().clamp(0.5, 2.0);
    }

    _bindAudioListeners();
    _refreshDownloadState();
    unawaited(_loadTimingForSelection(surah: _selectedSurah));
  }

  void _bindAudioListeners() {
    if (_useAudioplayersFallback) {
      _fallbackPositionSubscription = _fallbackAudio.onPositionChanged.listen((
        position,
      ) {
        if (_isScrubbing) return;
        _setAudioPosition(position);
      });

      _fallbackDurationSubscription = _fallbackAudio.onDurationChanged.listen((
        duration,
      ) {
        _safeSetState(() {
          _duration = duration;
        });
      });

      _fallbackStateSubscription = _fallbackAudio.onPlayerStateChanged.listen((
        state,
      ) {
        _safeSetState(() {
          _isPlaying = state == ap.PlayerState.playing;
          _isPaused = state == ap.PlayerState.paused;
          if (_isLoading) {
            if (_isPlaying) {
              _isLoading = false;
            }
          } else if (_isPaused || state == ap.PlayerState.stopped) {
            _isLoading = false;
          }
        });
        unawaited(
          AndroidAudioDisplayMode.setAudioPlaybackActive(
            state == ap.PlayerState.playing,
          ),
        );
        _syncProgressVisualPolicy();
      });

      _fallbackCompleteSubscription = _fallbackAudio.onPlayerComplete.listen((
        _,
      ) async {
        await _handleTrackComplete();
      });
      return;
    }

    _positionSubscription = _justAudio.positionStream.listen((position) {
      if (_isScrubbing) return;
      _setAudioPosition(position);
    });

    _durationSubscription = _justAudio.durationStream.listen((duration) {
      _safeSetState(() {
        _duration = duration ?? Duration.zero;
      });
    });

    _stateSubscription = _justAudio.playerStateStream.listen((state) async {
      _safeSetState(() {
        _isPlaying = state.playing;
        _isPaused =
            !state.playing && state.processingState == ja.ProcessingState.ready;
        if ((state.playing &&
                state.processingState == ja.ProcessingState.ready) ||
            state.processingState == ja.ProcessingState.completed) {
          _isLoading = false;
        }
      });

      if (state.processingState == ja.ProcessingState.completed) {
        await _handleTrackComplete();
      }
      unawaited(AndroidAudioDisplayMode.setAudioPlaybackActive(state.playing));
      _syncProgressVisualPolicy();
    });
  }

  Future<void> _handleTrackComplete() async {
    if (_isCompletingTrack) return;
    _isCompletingTrack = true;

    try {
      _safeSetState(() {
        _position = Duration.zero;
        _displayedPosition = Duration.zero;
        _activeAyah = null;
        _isPlaying = false;
        _isPaused = false;
      });
      _syncProgressVisualPolicy();

      if (_loopEnabled) {
        await _playSurah(_selectedSurah, forceRestart: true);
      } else if (_shuffleEnabled) {
        final int next = _randomSurah(excluding: _selectedSurah);
        await _playSurah(next, forceRestart: true);
      } else {
        await _playNext();
      }
    } finally {
      _isCompletingTrack = false;
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  bool get _shouldRenderProgressVisuals {
    return mounted && !_isScrubbing && _progressVisualBlockCount == 0;
  }

  bool get _shouldAnimateProgressVisuals {
    return _shouldRenderProgressVisuals && _isPlaying;
  }

  void _syncProgressVisualPolicy({bool syncPosition = false}) {
    if (!mounted) return;

    unawaited(
      AndroidAudioDisplayMode.setVisualProgressActive(
        _shouldAnimateProgressVisuals,
      ),
    );

    if (syncPosition && _shouldRenderProgressVisuals) {
      _syncDisplayedPosition();
    }
  }

  void _setAudioPosition(Duration position) {
    _position = position;
    final int? nextAyah = _activeAyahForPosition(position);
    final bool ayahChanged = nextAyah != _activeAyah;
    final bool progressChanged =
        _shouldRenderProgressVisuals && _displayedPosition != position;
    if (!progressChanged && !ayahChanged) return;

    setState(() {
      if (progressChanged) {
        _displayedPosition = position;
      }
      if (ayahChanged) {
        _activeAyah = nextAyah;
      }
    });
  }

  void _syncDisplayedPosition() {
    if (!mounted) return;
    if (_displayedPosition == _position) return;

    setState(() {
      _displayedPosition = _position;
    });
  }

  Future<T> _withProgressVisualsPaused<T>(Future<T> Function() action) async {
    AndroidAudioDisplayMode.notifyUserActivity();
    _progressVisualBlockCount++;
    _syncProgressVisualPolicy();
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));
    try {
      return await action();
    } finally {
      if (_progressVisualBlockCount > 0) {
        _progressVisualBlockCount--;
      }
      _syncProgressVisualPolicy(syncPosition: true);
      unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
    }
  }

  String _surahName(int surah) => _surahTransliterations[surah - 1];

  String _selectedReciterCode() => QuranAudioService().selectedReciter.code;

  String _selectedReciterName() =>
      QuranAudioService().selectedReciter.englishName;

  Future<String> _surahStreamUrl(int surah) =>
      QuranAudioService().getSurahUrl(surah);

  void _syncTimingForCurrentSelection() {
    final String reciterCode = _selectedReciterCode();
    if (_timingSurah == _selectedSurah && _timingReciterCode == reciterCode) {
      return;
    }
    final int targetSurah = _selectedSurah;
    _timingSurah = targetSurah;
    _timingReciterCode = reciterCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _selectedSurah != targetSurah ||
          _selectedReciterCode() != reciterCode) {
        return;
      }
      unawaited(
        _loadTimingForSelection(surah: targetSurah, reciterCode: reciterCode),
      );
    });
  }

  Future<void> _loadTimingForSelection({
    required int surah,
    String? reciterCode,
  }) async {
    final String effectiveReciterCode = reciterCode ?? _selectedReciterCode();
    final int generation = ++_timingLoadGeneration;

    _safeSetState(() {
      _timingSurah = surah;
      _timingReciterCode = effectiveReciterCode;
      _surahTiming = null;
      _activeAyah = null;
      _selectionTimingSupported = null;
      _isTimingLoading = true;
    });

    final bool hasTimingSupport =
        await SurahTimingRepository.hasTimingSupportForReciter(
          effectiveReciterCode,
        );
    if (!mounted || generation != _timingLoadGeneration) return;

    if (!hasTimingSupport) {
      _safeSetState(() {
        _selectionTimingSupported = false;
        _isTimingLoading = false;
      });
      return;
    }

    _safeSetState(() {
      _selectionTimingSupported = true;
    });

    final SurahTiming? timing = await _timingRepository.loadSurahTiming(
      reciterCode: effectiveReciterCode,
      surahNumber: surah,
    );
    if (!mounted || generation != _timingLoadGeneration) return;

    _safeSetState(() {
      _surahTiming = timing;
      _activeAyah = _activeAyahForPosition(_position);
      _selectionTimingSupported = true;
      _isTimingLoading = false;
    });
  }

  int? _activeAyahForPosition(Duration position) {
    final SurahTiming? timing = _surahTiming;
    if (timing == null) return null;
    final int? timedAyah = timing.timingForPosition(position)?.ayahNumber;
    if (timedAyah != null) return timedAyah;
    if (timing.ayahs.isEmpty) return null;
    return position < timing.ayahs.first.start
        ? 1
        : timing.ayahs.last.ayahNumber;
  }

  void _updateActiveAyah(Duration position) {
    final int? nextAyah = _activeAyahForPosition(position);
    if (nextAyah == _activeAyah) return;
    _safeSetState(() {
      _activeAyah = nextAyah;
    });
  }

  int _wrapSurah(int value) {
    if (value < 1) return 114;
    if (value > 114) return 1;
    return value;
  }

  int _randomSurah({required int excluding}) {
    int candidate = excluding;
    while (candidate == excluding) {
      candidate = _random.nextInt(114) + 1;
    }
    return candidate;
  }

  Future<File> _surahFile(int surah) async {
    return _downloads.surahFile(surah);
  }

  Future<bool> _hasOfflineFile(int surah) async {
    return _downloads.hasSurah(surah);
  }

  Future<void> _refreshDownloadState() async {
    final bool isDownloaded = await _hasOfflineFile(_selectedSurah);
    _safeSetState(() {
      _isDownloaded = isDownloaded;
    });
  }

  Future<void> _setPlaybackRate(double value) async {
    final double rate = _useAudioplayersFallback ? 1.0 : value.clamp(0.5, 2.0);
    _safeSetState(() {
      _playbackRate = rate;
    });
    await SettingsDB().put("playbackRate", rate);

    if (_useAudioplayersFallback) {
      await _fallbackAudio.setPlaybackRate(rate);
    } else {
      await _justAudio.setSpeed(rate);
    }
  }

  Future<void> _selectReciter(AppReciter reciter) async {
    if (reciter.code == _selectedReciterCode()) return;
    final bool shouldResumePlayback = _isPlaying || _isLoading;

    await SettingsDB().put("reciter", reciter.code);
    _loadedSurah = null;
    _loadedFromOffline = null;
    _loadedReciterCode = null;
    await _refreshDownloadState();

    if (shouldResumePlayback) {
      await _playSurah(_selectedSurah, forceRestart: true);
      return;
    }

    await _stopCurrentTrack();
    _safeSetState(() {
      _position = Duration.zero;
      _displayedPosition = Duration.zero;
      _duration = Duration.zero;
      _playingFromOffline = false;
    });
    unawaited(
      _loadTimingForSelection(surah: _selectedSurah, reciterCode: reciter.code),
    );
  }

  Future<void> _startTrack({
    required int surah,
    required bool playOffline,
  }) async {
    if (_useAudioplayersFallback) {
      await _fallbackAudio.stop();
      _safeSetState(() {
        _position = Duration.zero;
        _displayedPosition = Duration.zero;
        _duration = Duration.zero;
        _activeAyah = null;
      });

      if (playOffline) {
        final File file = await _surahFile(surah);
        await _fallbackAudio.play(ap.DeviceFileSource(file.path));
      } else {
        final String url = await _surahStreamUrl(surah);
        await _fallbackAudio.play(ap.UrlSource(url));
      }
      await _fallbackAudio.setPlaybackRate(_playbackRate);
      return;
    }

    final Uri sourceUri;
    if (playOffline) {
      final File file = await _surahFile(surah);
      sourceUri = Uri.file(file.path);
    } else {
      final String url = await _surahStreamUrl(surah);
      sourceUri = Uri.parse(url);
    }

    _safeSetState(() {
      _position = Duration.zero;
      _displayedPosition = Duration.zero;
      _duration = Duration.zero;
      _activeAyah = null;
    });

    await _justAudio.setAudioSource(
      ja.AudioSource.uri(
        sourceUri,
        tag: MediaItem(
          id: 'surah-$surah-${playOffline ? "offline" : "stream"}',
          album: 'eQuran',
          title: _surahName(surah),
          artist: _selectedReciterName(),
          displayDescription: 'Surah $surah',
        ),
      ),
    );
    await _justAudio.setSpeed(_playbackRate);
    unawaited(_justAudio.play());
  }

  Future<void> _resumeCurrentTrack() async {
    if (_useAudioplayersFallback) {
      await _fallbackAudio.resume();
      await _fallbackAudio.setPlaybackRate(_playbackRate);
    } else {
      unawaited(_justAudio.play());
      await _justAudio.setSpeed(_playbackRate);
    }
  }

  Future<void> _pauseCurrentTrack() async {
    if (_useAudioplayersFallback) {
      await _fallbackAudio.pause();
    } else {
      await _justAudio.pause();
    }
    _safeSetState(() {
      _isPlaying = false;
      _isPaused = true;
    });
    await AndroidAudioDisplayMode.setAudioPlaybackActive(false);
    _syncProgressVisualPolicy();
  }

  Future<void> _stopCurrentTrack() async {
    if (_useAudioplayersFallback) {
      await _fallbackAudio.stop();
    } else {
      await _justAudio.stop();
    }
    _safeSetState(() {
      _isPlaying = false;
      _isPaused = false;
      _activeAyah = null;
    });
    await AndroidAudioDisplayMode.setAudioPlaybackActive(false);
    _syncProgressVisualPolicy();
  }

  Future<void> _seekCurrentTrack(Duration position) async {
    if (_useAudioplayersFallback) {
      await _fallbackAudio.seek(position);
    } else {
      await _justAudio.seek(position);
    }
  }

  Future<void> _playSurah(int surah, {bool forceRestart = false}) async {
    final String reciterCode = _selectedReciterCode();
    unawaited(_loadTimingForSelection(surah: surah, reciterCode: reciterCode));
    _safeSetState(() {
      _selectedSurah = surah;
      _isLoading = true;
    });

    try {
      final bool shouldPlayOffline = await _hasOfflineFile(surah);

      _safeSetState(() {
        _selectedSurah = surah;
        _isDownloaded = shouldPlayOffline;
        _playingFromOffline = shouldPlayOffline;
      });

      final bool sameTrack =
          _loadedSurah == surah &&
          _loadedFromOffline == shouldPlayOffline &&
          _loadedReciterCode == reciterCode &&
          !forceRestart;

      if (sameTrack && _isPaused) {
        await _resumeCurrentTrack();
      } else {
        await _startTrack(surah: surah, playOffline: shouldPlayOffline);
        _loadedSurah = surah;
        _loadedFromOffline = shouldPlayOffline;
        _loadedReciterCode = reciterCode;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to play surah audio.')),
        );
      }
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isLoading) return;
    if (_isPlaying) {
      await _pauseCurrentTrack();
      return;
    }
    await _playSurah(_selectedSurah);
  }

  Future<void> _playPrevious() async {
    await _playSurah(_wrapSurah(_selectedSurah - 1), forceRestart: true);
  }

  Future<void> _playNext() async {
    final int nextSurah = _shuffleEnabled
        ? _randomSurah(excluding: _selectedSurah)
        : _wrapSurah(_selectedSurah + 1);
    await _playSurah(nextSurah, forceRestart: true);
  }

  Future<void> _seek(double fraction) async {
    if (_duration.inMilliseconds <= 0) return;
    final int ms = (_duration.inMilliseconds * fraction).round();
    await _seekCurrentTrack(Duration(milliseconds: ms));
  }

  Duration _positionForProgress() {
    return _scrubPreviewPosition ?? _displayedPosition;
  }

  void _revealProgressThumb() {
    _progressThumbTimer?.cancel();
    if (!_showProgressThumb && mounted) {
      setState(() {
        _showProgressThumb = true;
      });
    }
  }

  void _hideProgressThumbSoon() {
    _progressThumbTimer?.cancel();
    _progressThumbTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _showProgressThumb = false;
      });
    });
  }

  Widget _buildProgressSlider({
    required BuildContext context,
    required double progress,
  }) {
    final SliderThemeData sliderTheme = AppSliderTheme.standard(context);
    return SliderTheme(
      data: sliderTheme.copyWith(
        overlayColor: _showProgressThumb
            ? sliderTheme.overlayColor
            : Colors.transparent,
      ),
      child: Slider(
        value: (_pendingSeekProgress ?? progress).clamp(0.0, 1.0),
        onChangeStart: (value) {
          AndroidAudioDisplayMode.notifyUserActivity();
          unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));
          _revealProgressThumb();
          _safeSetState(() {
            _isScrubbing = true;
            _pendingSeekProgress = value;
            final int pendingMs = (_duration.inMilliseconds * value).round();
            _scrubPreviewPosition = Duration(milliseconds: pendingMs);
          });
          _syncProgressVisualPolicy();
        },
        onChanged: (value) {
          _revealProgressThumb();
          _safeSetState(() {
            _pendingSeekProgress = value;
            final int pendingMs = (_duration.inMilliseconds * value).round();
            _scrubPreviewPosition = Duration(milliseconds: pendingMs);
          });
        },
        onChangeEnd: (value) async {
          _hideProgressThumbSoon();
          final int pendingMs = (_duration.inMilliseconds * value).round();
          try {
            await _seek(value);
          } finally {
            _safeSetState(() {
              _position = Duration(milliseconds: pendingMs);
              _displayedPosition = Duration(milliseconds: pendingMs);
              _isScrubbing = false;
              _pendingSeekProgress = null;
              _scrubPreviewPosition = null;
            });
            _updateActiveAyah(Duration(milliseconds: pendingMs));
            _syncProgressVisualPolicy();
            unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
          }
        },
      ),
    );
  }

  Future<void> _selectSurah(int? surah) async {
    if (surah == null) return;
    await _playSurah(surah, forceRestart: true);
  }

  Widget _buildSurahSelectionList({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool closeOnSelect,
    ScrollController? scrollController,
  }) {
    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      itemCount: 114,
      itemBuilder: (context, index) {
        final int surah = index + 1;
        final bool isSelected = surah == _selectedSurah;
        return ListTile(
          selected: isSelected,
          selectedTileColor: Colors.transparent,
          tileColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          selectedColor: colorScheme.onSurface,
          textColor: colorScheme.onSurface,
          iconColor: colorScheme.onSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          onTap: () async {
            if (closeOnSelect) {
              Navigator.of(context).pop(surah);
              return;
            }
            await _selectSurah(surah);
          },
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: isSelected
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerLow,
            child: Text(
              surah.toString(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(_surahName(surah)),
          subtitle: Text('Surah $surah'),
          trailing: isSelected
              ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
              : null,
        );
      },
    );
  }

  Widget _buildSurahSelectionPane({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: const SizedBox.expand(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colorScheme.surface.withValues(alpha: 0.14),
                  colorScheme.surfaceContainerHigh.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.36),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'Choose Surah',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.28),
              ),
              Expanded(
                child: _buildSurahSelectionList(
                  theme: theme,
                  colorScheme: colorScheme,
                  closeOnSelect: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openSurahPickerSheet() async {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int? selectedSurah = await _withProgressVisualsPaused(() {
      return showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.large),
          ),
        ),
        builder: (context) {
          final double screenHeight = MediaQuery.sizeOf(context).height;
          final double initialSize = min(
            0.62,
            520 / screenHeight,
          ).clamp(0.42, 0.62).toDouble();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: initialSize,
            minChildSize: 0.32,
            maxChildSize: 0.94,
            builder: (context, scrollController) {
              return Material(
                color: colorScheme.surfaceContainer,
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(
                        'Choose Surah',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _buildSurahSelectionList(
                        theme: theme,
                        colorScheme: colorScheme,
                        closeOnSelect: true,
                        scrollController: scrollController,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    });

    await _selectSurah(selectedSurah);
  }

  Future<void> _showPlayerOptionsSheet() async {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    await _withProgressVisualsPaused(() {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: colorScheme.surfaceContainer,
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.large),
          ),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> selectReciter() async {
                final AppReciter? selected = await _showReciterPickerDialog();
                if (selected == null || !mounted) return;
                await _selectReciter(selected);
                if (sheetContext.mounted) setSheetState(() {});
              }

              Future<void> openSurahPicker() async {
                Navigator.of(sheetContext).pop();
                await _openSurahPickerSheet();
              }

              Future<void> handleDownload() async {
                if (_isDownloaded) {
                  await _confirmDeleteSurahDownload();
                } else if (!_isDownloading) {
                  await _downloadSurah();
                }
                if (sheetContext.mounted) setSheetState(() {});
              }

              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.68,
                minChildSize: 0.38,
                maxChildSize: 0.92,
                builder: (context, scrollController) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(18),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Player options',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildPlayerOptionsSection(
                        context: context,
                        title: 'Recitation',
                        children: <Widget>[
                          ListTile(
                            leading: const Icon(Icons.queue_music_rounded),
                            title: const Text('Surah'),
                            subtitle: Text(_surahName(_selectedSurah)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: openSurahPicker,
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.record_voice_over_rounded,
                            ),
                            title: const Text('Reciter'),
                            subtitle: Text(_selectedReciterName()),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: selectReciter,
                          ),
                          _buildSliderOption(
                            context: context,
                            title: 'Playback speed',
                            subtitle: '${_playbackRate.toStringAsFixed(2)}x',
                            value: _playbackRate,
                            min: 0.5,
                            max: 2.0,
                            divisions: 6,
                            label: '${_playbackRate.toStringAsFixed(2)}x',
                            onChanged: _useAudioplayersFallback
                                ? null
                                : (value) async {
                                    final double normalized =
                                        (value * 4).round() / 4;
                                    await _setPlaybackRate(normalized);
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildPlayerOptionsSection(
                        context: context,
                        title: 'Offline',
                        children: <Widget>[
                          ListTile(
                            leading: _isDownloading
                                ? SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : Icon(
                                    _isDownloaded
                                        ? Icons.check_circle_rounded
                                        : Icons.download_rounded,
                                    color: _isDownloaded
                                        ? colorScheme.primary
                                        : null,
                                  ),
                            title: Text(
                              _isDownloaded
                                  ? 'Delete downloaded MP3'
                                  : 'Download MP3',
                            ),
                            subtitle: Text(
                              _isDownloaded ? 'Available offline' : 'Not saved',
                            ),
                            onTap: _isDownloading ? null : handleDownload,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildPlayerOptionsSection(
                        context: context,
                        title: 'Playback',
                        children: <Widget>[
                          SwitchListTile(
                            secondary: const Icon(Icons.shuffle_rounded),
                            title: const Text('Shuffle'),
                            subtitle: Text(
                              _shuffleEnabled ? 'Enabled' : 'Disabled',
                            ),
                            value: _shuffleEnabled,
                            onChanged: (value) {
                              setState(() {
                                _shuffleEnabled = value;
                              });
                              setSheetState(() {});
                            },
                          ),
                          SwitchListTile(
                            secondary: const Icon(Icons.repeat_rounded),
                            title: const Text('Loop current surah'),
                            subtitle: Text(
                              _loopEnabled ? 'Enabled' : 'Disabled',
                            ),
                            value: _loopEnabled,
                            onChanged: (value) {
                              setState(() {
                                _loopEnabled = value;
                              });
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    });
  }

  Widget _buildPlayerOptionsSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSliderOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double>? onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(subtitle),
          Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value.clamp(min, max).toDouble(),
            label: label,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<AppReciter?> _showReciterPickerDialog() {
    final List<AppReciter> reciters = AppReciter.values.toList()
      ..sort(
        (a, b) =>
            a.englishName.toLowerCase().compareTo(b.englishName.toLowerCase()),
      );
    return showDialog<AppReciter>(
      context: context,
      builder: (context) => AppSelectionDialog<AppReciter>(
        title: 'Reciter',
        icon: Icons.record_voice_over_rounded,
        selectedValue: QuranAudioService().selectedReciter,
        options: reciters
            .map(
              (reciter) => AppSelectionOption<AppReciter>(
                value: reciter,
                title: reciter.englishName,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _downloadSurah() async {
    _safeSetState(() {
      _isDownloading = true;
    });

    try {
      final int notificationId = DownloadNotifications.notificationId(
        'surah-$_selectedSurah',
      );
      final String title = 'Downloading ${_surahName(_selectedSurah)}';
      await DownloadNotifications.progress(
        id: notificationId,
        title: title,
        progress: null,
      );
      await _downloads.downloadSurah(
        _selectedSurah,
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
        title: 'Downloaded ${_surahName(_selectedSurah)}',
      );
      await _refreshDownloadState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${_surahName(_selectedSurah)}')),
        );
      }
    } catch (_) {
      await DownloadNotifications.fail(
        id: DownloadNotifications.notificationId('surah-$_selectedSurah'),
        title: 'Failed to download ${_surahName(_selectedSurah)}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download surah audio.')),
        );
      }
    } finally {
      _safeSetState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _deleteSurahDownloadConfirmed() async {
    try {
      await _downloads.deleteSurah(_selectedSurah);

      if (_playingFromOffline && _loadedSurah == _selectedSurah) {
        await _stopCurrentTrack();
        _loadedSurah = null;
        _loadedFromOffline = null;
        _loadedReciterCode = null;
        _safeSetState(() {
          _position = Duration.zero;
          _displayedPosition = Duration.zero;
          _duration = Duration.zero;
          _activeAyah = null;
          _isPlaying = false;
          _isPaused = false;
          _playingFromOffline = false;
        });
      }

      await _refreshDownloadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${_surahName(_selectedSurah)} MP3')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete downloaded surah.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteSurahDownload() async {
    final bool? confirm = await _withProgressVisualsPaused(() {
      return showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded),
            title: const Text('Delete Downloaded MP3?'),
            content: Text(
              'This will remove ${_surahName(_selectedSurah)} from offline storage.',
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
          );
        },
      );
    });

    if (confirm == true) {
      await _deleteSurahDownloadConfirmed();
    }
  }

  @override
  void dispose() {
    unawaited(AndroidAudioDisplayMode.setAudioPlaybackActive(false));
    unawaited(AndroidAudioDisplayMode.setVisualProgressActive(false));
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
    unawaited(AndroidAudioDisplayMode.setLimitedProgressFrameRate(0));
    _progressThumbTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _fallbackPositionSubscription?.cancel();
    _fallbackDurationSubscription?.cancel();
    _fallbackStateSubscription?.cancel();
    _fallbackCompleteSubscription?.cancel();

    _justAudio.dispose();
    _fallbackAudio.dispose();
    super.dispose();
  }

  void _notifyAudioUserActivity() {
    AndroidAudioDisplayMode.notifyUserActivity();
  }

  Widget _buildAudioInteractionBoundary({required Widget child}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _notifyAudioUserActivity(),
      onPointerMove: (_) => _notifyAudioUserActivity(),
      onPointerSignal: (_) => _notifyAudioUserActivity(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _notifyAudioUserActivity();
          return false;
        },
        child: child,
      ),
    );
  }

  String? _timingStatusText() {
    if (_isTimingLoading) return 'Loading synced ayah';
    if (_surahTiming != null) return null;
    if (_selectionTimingSupported == false) {
      return 'Synced ayah display is unavailable for this reciter';
    }
    if (_selectionTimingSupported == true) {
      return 'Synced ayah display is unavailable for this surah';
    }
    return null;
  }

  Widget _buildActiveAyahCard({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final String? statusText = _timingStatusText();
    if (statusText != null) {
      return _buildPlayerMessageCard(
        theme: theme,
        colorScheme: colorScheme,
        message: statusText,
        loading: _isTimingLoading,
      );
    }

    final int ayah = _displayedAyah();
    final bool showTransliteration =
        SettingsDB().get("showTransliteration", defaultValue: false) == true;
    final bool showTranslation =
        SettingsDB().get("enableTranslation", defaultValue: true) == true;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: double.infinity,
          child: ReadQuranCard(
            key: ValueKey<String>('player-ayah-$_selectedSurah-$ayah'),
            currentChapter: _selectedSurah,
            currentVerse: ayah,
            totalVerses: quran.getVerseCount(_selectedSurah),
            juzNumber: quran.getJuzNumber(_selectedSurah, ayah),
            basmala: _selectedSurah != 1 && ayah == 1 && _selectedSurah != 9
                ? quran.basmala
                : null,
            verse: quranVerseText(_selectedSurah, ayah),
            translation: quran.getVerseTranslation(
              _selectedSurah,
              ayah,
              translation: quran.Translation.values[_translationIndex()],
            ),
            transliteration: showTransliteration
                ? _cardTransliterationForAyah(ayah)
                : '',
            showActions: false,
            showTransliteration: showTransliteration,
            showTranslation: showTranslation,
            fontSize: _doubleSetting("fontSize", 31.0),
            fontSizeTranslation: _doubleSetting("fontSizeTranslation", 12.0),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerMessageCard({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String message,
    required bool loading,
  }) {
    return Center(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        elevation: theme.brightness == Brightness.light ? 3 : 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(
            color: theme.brightness == Brightness.light
                ? colorScheme.primary.withAlpha(28)
                : colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (loading)
                SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: colorScheme.primary,
                  ),
                )
              else
                Icon(
                  Icons.sync_problem_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _displayedAyah() {
    final int ayahCount = quran.getVerseCount(_selectedSurah);
    return (_activeAyah ?? 1).clamp(1, ayahCount).toInt();
  }

  int _translationIndex() {
    final dynamic savedIndex = SettingsDB().get("translation", defaultValue: 0);
    if (savedIndex is num) {
      return savedIndex.toInt().clamp(0, quran.Translation.values.length - 1);
    }
    return 0;
  }

  double _doubleSetting(String key, double defaultValue) {
    final dynamic value = SettingsDB().get(key, defaultValue: defaultValue);
    return value is num ? value.toDouble() : defaultValue;
  }

  Future<void> _loadSelectedSurahTransliterations() async {
    final int surah = _selectedSurah;
    final List<String> transliterations = await QuranTransliterationService
        .instance
        .versesForSurah(surah);
    if (!mounted || surah != _selectedSurah) return;
    setState(() {
      _transliterationSurah = surah;
      _surahTransliterationsCache = transliterations;
    });
  }

  String _cardTransliterationForAyah(int ayah) {
    if (_transliterationSurah != _selectedSurah) {
      unawaited(_loadSelectedSurahTransliterations());
      return '';
    }
    if (ayah < 1 || ayah > _surahTransliterationsCache.length) return '';
    return _surahTransliterationsCache[ayah - 1].trim();
  }

  @override
  Widget build(BuildContext context) {
    _syncTimingForCurrentSelection();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Duration displayedPosition = _positionForProgress();
    final double progress = _duration.inMilliseconds > 0
        ? (displayedPosition.inMilliseconds / _duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        final Size mediaSize = mediaQuery.size;
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final bool hasFoldableDisplayFeature = mediaQuery.displayFeatures.any((
          DisplayFeature feature,
        ) {
          return feature.type == DisplayFeatureType.hinge ||
              feature.type == DisplayFeatureType.fold;
        });
        final bool isFoldableLayout = hasFoldableDisplayFeature && width >= 720;
        final bool isLargeLandscapeTablet =
            !hasFoldableDisplayFeature &&
            mediaSize.shortestSide >= 720 &&
            mediaSize.longestSide >= 1180 &&
            mediaSize.width > mediaSize.height;
        final bool isExtraLargeTablet =
            !hasFoldableDisplayFeature &&
            mediaSize.shortestSide >= 900 &&
            width >= 1100;
        final bool isDesktop =
            !isFoldableLayout &&
            (width >= 1250 || isLargeLandscapeTablet || isExtraLargeTablet);
        final bool isCompactWidescreenLayout = isDesktop && width < 1250;
        final double desktopHeightScale = isDesktop
            ? ((height - 540) / 260).clamp(0.78, 1.0).toDouble()
            : 1.0;
        final double desktopBottomBarMinHeight =
            (width >= 1500 ? 132 : 124) * desktopHeightScale;
        final double desktopBottomBarVerticalPadding = 18 * desktopHeightScale;
        final double playerControlIconSize = isDesktop
            ? (34 * desktopHeightScale).clamp(28.0, 34.0).toDouble()
            : 34.0;
        final double playButtonPadding = isDesktop
            ? (20 * desktopHeightScale).clamp(15.0, 20.0).toDouble()
            : 20.0;
        final double playButtonSize =
            playerControlIconSize + (playButtonPadding * 2);
        final double loadingIndicatorSize = isDesktop
            ? (30 * desktopHeightScale).clamp(24.0, 30.0).toDouble()
            : 30.0;
        final double foldableRightPanelLift = isFoldableLayout
            ? (height * 0.035).clamp(18.0, 32.0).toDouble()
            : 0.0;
        final double maxContentWidth = isDesktop
            ? width
            : isFoldableLayout
            ? min(width, 1000)
            : 560;
        final double desktopCenterWidth = isCompactWidescreenLayout
            ? (width * 0.54).clamp(380.0, 500.0).toDouble()
            : (width * 0.45).clamp(600.0, 740.0).toDouble();
        final double timeLabelWidth = _duration.inHours > 0 ? 76.0 : 56.0;

        Widget buildTimeLabel(
          Duration value, {
          TextAlign textAlign = TextAlign.left,
        }) {
          return SizedBox(
            width: timeLabelWidth,
            child: Text(
              formatDurationLabel(value),
              maxLines: 1,
              softWrap: false,
              textAlign: textAlign,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        final header = Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 14 : 8),
          child: Row(
            children: <Widget>[
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  style: ResponsiveNav.iconButtonStyle(context),
                  icon: Icon(
                    Icons.menu_rounded,
                    size: ResponsiveNav.iconSize(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _surahName(_selectedSurah),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style:
                          (isDesktop
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedReciterName(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Player options',
                onPressed: _showPlayerOptionsSheet,
                style: ResponsiveNav.iconButtonStyle(context),
                icon: Icon(
                  Icons.more_horiz,
                  size: ResponsiveNav.iconSize(context),
                ),
              ),
            ],
          ),
        );

        Widget buildPlayPauseChild() {
          return SizedBox.square(
            dimension: playerControlIconSize,
            child: Center(
              child: _isLoading
                  ? SizedBox(
                      width: loadingIndicatorSize,
                      height: loadingIndicatorSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: playerControlIconSize,
                    ),
            ),
          );
        }

        Widget buildPlayPauseButton() {
          return SizedBox.square(
            dimension: playButtonSize,
            child: FilledButton(
              onPressed: _togglePlayPause,
              style: FilledButton.styleFrom(
                fixedSize: Size.square(playButtonSize),
                minimumSize: Size.square(playButtonSize),
                maximumSize: Size.square(playButtonSize),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: buildPlayPauseChild(),
            ),
          );
        }

        Widget buildTransportControls({double gap = 12}) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: 'Previous',
                onPressed: _playPrevious,
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: playerControlIconSize,
              ),
              SizedBox(width: gap),
              buildPlayPauseButton(),
              SizedBox(width: gap),
              IconButton(
                tooltip: 'Next',
                onPressed: _playNext,
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: playerControlIconSize,
              ),
            ],
          );
        }

        final Widget activeAyahCard = _buildActiveAyahCard(
          theme: theme,
          colorScheme: colorScheme,
        );

        final Widget playbackPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildProgressSlider(context: context, progress: progress),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                buildTimeLabel(displayedPosition),
                buildTimeLabel(_duration, textAlign: TextAlign.right),
              ],
            ),
            const SizedBox(height: 8),
            buildTransportControls(gap: isDesktop ? 10 : 14),
          ],
        );

        final Widget desktopBottomBar = Container(
          padding: EdgeInsets.symmetric(
            horizontal: max(18, 24 * desktopHeightScale),
            vertical: desktopBottomBarVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: desktopBottomBarMinHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: desktopCenterWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    buildTransportControls(gap: 10),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        buildTimeLabel(displayedPosition),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildProgressSlider(
                            context: context,
                            progress: progress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        buildTimeLabel(_duration, textAlign: TextAlign.right),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final Widget foldableNowPlaying = Transform.translate(
          offset: Offset(0, -foldableRightPanelLift),
          child: Padding(
            padding: EdgeInsets.only(bottom: foldableRightPanelLift),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: activeAyahCard),
                const SizedBox(height: 12),
                playbackPanel,
              ],
            ),
          ),
        );

        final Widget mobileNowPlaying = Transform.translate(
          offset: const Offset(0, -6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: activeAyahCard),
              const SizedBox(height: 10),
              playbackPanel,
            ],
          ),
        );

        final Widget bodyContent = isDesktop
            ? Column(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: activeAyahCard,
                    ),
                  ),
                  const SizedBox(height: 16),
                  desktopBottomBar,
                ],
              )
            : isFoldableLayout
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _buildSurahSelectionPane(
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: foldableNowPlaying),
                ],
              )
            : mobileNowPlaying;

        return _buildAudioInteractionBoundary(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  colorScheme.primaryContainer.withValues(alpha: 0.60),
                  colorScheme.tertiaryContainer.withValues(alpha: 0.35),
                  colorScheme.surface,
                ],
              ),
            ),
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          header,
                          Expanded(child: bodyContent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
