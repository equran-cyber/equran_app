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
        SettingsDB;
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/app_slider_theme.dart';
import 'package:equran/utils/number_formatting.dart';
import 'package:equran/utils/responsive_nav.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:equran/backend/library.dart' show QuranAudioService;

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
  final ja.AudioPlayer _justAudio = ja.AudioPlayer();
  final ap.AudioPlayer _fallbackAudio = ap.AudioPlayer();
  final AudioDownloadService _downloads = AudioDownloadService();
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

  bool _isLoading = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _playingFromOffline = false;
  bool _shuffleEnabled = false;
  bool _loopEnabled = false;
  bool _isCompletingTrack = false;
  bool _showProgressThumb = false;
  bool _isScrubbing = false;
  double? _pendingSeekProgress;
  Duration? _scrubPreviewPosition;

  double _playbackRate = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _progressThumbTimer;

  @override
  void initState() {
    super.initState();

    _useAudioplayersFallback =
        !kIsWeb && (Platform.isLinux || Platform.isWindows);

    final dynamic rate = SettingsDB().get("playbackRate", defaultValue: 1.0);
    if (rate is num) {
      _playbackRate = rate.toDouble().clamp(0.5, 2.0);
    }

    _bindAudioListeners();
    _refreshDownloadState();
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(true));
  }

  void _bindAudioListeners() {
    if (_useAudioplayersFallback) {
      _fallbackPositionSubscription = _fallbackAudio.onPositionChanged.listen((
        position,
      ) {
        if (_isScrubbing) return;
        _safeSetState(() {
          _position = position;
        });
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
      _safeSetState(() {
        _position = position;
      });
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
    });
  }

  Future<void> _handleTrackComplete() async {
    if (_isCompletingTrack) return;
    _isCompletingTrack = true;

    try {
      _safeSetState(() {
        _position = Duration.zero;
        _isPlaying = false;
        _isPaused = false;
      });

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

  String _surahName(int surah) => _surahTransliterations[surah - 1];

  String _selectedReciterName() =>
      QuranAudioService().selectedReciter.englishName;

  Future<String> _surahStreamUrl(int surah) =>
      QuranAudioService().getSurahUrl(surah);

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

  Future<void> _startTrack({
    required int surah,
    required bool playOffline,
  }) async {
    if (_useAudioplayersFallback) {
      await _fallbackAudio.stop();
      _safeSetState(() {
        _position = Duration.zero;
        _duration = Duration.zero;
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

    await _justAudio.setAudioSource(
      ja.AudioSource.uri(
        sourceUri,
        tag: MediaItem(
          id: 'surah-$surah-${playOffline ? "offline" : "stream"}',
          album: 'eQuran',
          title: _surahName(surah),
          artist: '',
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
    await AndroidAudioDisplayMode.setAudioPlaybackActive(false);
  }

  Future<void> _stopCurrentTrack() async {
    if (_useAudioplayersFallback) {
      await _fallbackAudio.stop();
    } else {
      await _justAudio.stop();
    }
    await AndroidAudioDisplayMode.setAudioPlaybackActive(false);
  }

  Future<void> _seekCurrentTrack(Duration position) async {
    if (_useAudioplayersFallback) {
      await _fallbackAudio.seek(position);
    } else {
      await _justAudio.seek(position);
    }
  }

  Future<void> _playSurah(int surah, {bool forceRestart = false}) async {
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
          !forceRestart;

      if (sameTrack && _isPaused) {
        await _resumeCurrentTrack();
      } else {
        await _startTrack(surah: surah, playOffline: shouldPlayOffline);
        _loadedSurah = surah;
        _loadedFromOffline = shouldPlayOffline;
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
    return _scrubPreviewPosition ?? _position;
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
          _revealProgressThumb();
          _safeSetState(() {
            _isScrubbing = true;
            _pendingSeekProgress = value;
            final int pendingMs = (_duration.inMilliseconds * value).round();
            _scrubPreviewPosition = Duration(milliseconds: pendingMs);
          });
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
              _isScrubbing = false;
              _pendingSeekProgress = null;
              _scrubPreviewPosition = null;
            });
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
    final int? selectedSurah = await showModalBottomSheet<int>(
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

    await _selectSurah(selectedSurah);
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
        _safeSetState(() {
          _position = Duration.zero;
          _duration = Duration.zero;
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
    final bool? confirm = await showDialog<bool>(
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

    if (confirm == true) {
      await _deleteSurahDownloadConfirmed();
    }
  }

  @override
  void dispose() {
    unawaited(AndroidAudioDisplayMode.setAudioPlaybackActive(false));
    unawaited(AndroidAudioDisplayMode.setLowFpsSuppressed(false));
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Duration displayedPosition = _positionForProgress();
    final double progress = _duration.inMilliseconds > 0
        ? (displayedPosition.inMilliseconds / _duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    final List<double> playbackRates = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

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
        final double actionIconSize = isDesktop
            ? (28 * desktopHeightScale).clamp(24.0, 28.0).toDouble()
            : 28.0;
        final double foldableRightPanelLift = isFoldableLayout
            ? (height * 0.035).clamp(18.0, 32.0).toDouble()
            : 0.0;
        final double maxContentWidth = isDesktop
            ? width
            : isFoldableLayout
            ? min(width, 1000)
            : 560;
        final double maxArtHeight = isDesktop
            ? height -
                  76 -
                  20 -
                  desktopBottomBarMinHeight -
                  (desktopBottomBarVerticalPadding * 2) -
                  24
            : isFoldableLayout
            ? height - 380
            : height - 360;
        final double artSize = min(
          isDesktop
              ? 520
              : isFoldableLayout
              ? min(width * 0.34, 300)
              : min(width - 56, 440),
          max(isDesktop ? 120 : 180, maxArtHeight),
        );
        final double artIconSize = isDesktop
            ? min(170 * desktopHeightScale, artSize * 0.38)
            : 130;
        final double bottomBarArtworkSize =
            (isCompactWidescreenLayout ? 64 : 84) * desktopHeightScale;
        final double bottomBarCenterGap =
            (isCompactWidescreenLayout ? 56 : 150) * desktopHeightScale;
        final double desktopCenterWidth = isCompactWidescreenLayout
            ? (width * 0.54).clamp(380.0, 500.0).toDouble()
            : (width * 0.45).clamp(600.0, 740.0).toDouble();
        final double desktopMetadataMaxWidth = max(
          isCompactWidescreenLayout ? 128.0 : 220.0,
          ((width - desktopCenterWidth) / 2) -
              bottomBarArtworkSize -
              (isCompactWidescreenLayout ? 12 : 18) -
              56,
        );
        final double effectiveContentWidth = min(maxContentWidth, width);
        final double headerLeftOffset =
            -(((width - effectiveContentWidth) / 2).clamp(
                  0.0,
                  double.infinity,
                ) +
                16);
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
          padding: EdgeInsets.only(bottom: isDesktop ? 24 : 16),
          child: Transform.translate(
            offset: Offset(headerLeftOffset, 0),
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
                const Spacer(),
              ],
            ),
          ),
        );

        final Widget speedButton = MenuAnchor(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(
              colorScheme.surfaceContainer,
            ),
            surfaceTintColor: WidgetStatePropertyAll(colorScheme.surfaceTint),
            elevation: const WidgetStatePropertyAll(6),
            side: WidgetStatePropertyAll(
              BorderSide(color: colorScheme.outlineVariant),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: null,
              leadingIcon: const Icon(Icons.speed_rounded),
              child: Text(
                'Playback Speed',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            ...playbackRates.map(
              (rate) => MenuItemButton(
                onPressed: (!_useAudioplayersFallback || rate == 1.0)
                    ? () => _setPlaybackRate(rate)
                    : null,
                leadingIcon: const Icon(Icons.tune_rounded),
                trailingIcon: _playbackRate == rate
                    ? Icon(Icons.check_rounded, color: colorScheme.primary)
                    : null,
                child: Text('${rate}x'),
              ),
            ),
          ],
          builder: (context, controller, child) => IconButton(
            tooltip: 'Playback Speed',
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Icon(Icons.speed_rounded, size: actionIconSize),
          ),
        );

        final Widget downloadButton = _isDownloaded
            ? IconButton(
                tooltip: 'Delete downloaded MP3',
                onPressed: _confirmDeleteSurahDownload,
                icon: Icon(
                  Icons.check_circle_rounded,
                  size: actionIconSize,
                  color: colorScheme.primary,
                ),
              )
            : IconButton(
                tooltip: 'Download MP3',
                onPressed: _isDownloading ? null : _downloadSurah,
                icon: _isDownloading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.download_rounded, size: actionIconSize),
              );

        Widget buildArtworkSquare({
          required double panelArtSize,
          required double panelIconSize,
        }) {
          return Container(
            width: panelArtSize,
            height: panelArtSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.medium),
              gradient: LinearGradient(
                colors: <Color>[
                  colorScheme.primaryContainer,
                  colorScheme.tertiaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              size: panelIconSize,
              color: colorScheme.onPrimaryContainer,
            ),
          );
        }

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

        Widget buildArtworkActions() {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              if (!isFoldableLayout)
                IconButton(
                  tooltip: 'Choose Surah',
                  onPressed: _openSurahPickerSheet,
                  icon: const Icon(Icons.queue_music_rounded),
                ),
              speedButton,
              downloadButton,
            ],
          );
        }

        Widget buildArtworkPanel({
          required double panelArtSize,
          required double panelIconSize,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: buildArtworkSquare(
                  panelArtSize: panelArtSize,
                  panelIconSize: panelIconSize,
                ),
              ),
              const SizedBox(height: 10),
              buildArtworkActions(),
            ],
          );
        }

        final Widget artworkPanel = buildArtworkPanel(
          panelArtSize: artSize,
          panelIconSize: artIconSize,
        );

        final Widget playbackPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _surahName(_selectedSurah),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedReciterName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Surah $_selectedSurah',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                IconButton(
                  tooltip: 'Shuffle',
                  onPressed: () {
                    _safeSetState(() {
                      _shuffleEnabled = !_shuffleEnabled;
                    });
                  },
                  icon: const Icon(Icons.shuffle_rounded),
                  color: _shuffleEnabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                IconButton(
                  tooltip: 'Previous',
                  onPressed: _playPrevious,
                  icon: const Icon(Icons.skip_previous_rounded),
                  iconSize: playerControlIconSize,
                ),
                buildPlayPauseButton(),
                IconButton(
                  tooltip: 'Next',
                  onPressed: _playNext,
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: playerControlIconSize,
                ),
                IconButton(
                  tooltip: 'Loop',
                  onPressed: () {
                    _safeSetState(() {
                      _loopEnabled = !_loopEnabled;
                    });
                  },
                  icon: const Icon(Icons.repeat_rounded),
                  color: _loopEnabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
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
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: bottomBarArtworkSize,
                            height: bottomBarArtworkSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                              gradient: LinearGradient(
                                colors: <Color>[
                                  colorScheme.primaryContainer,
                                  colorScheme.tertiaryContainer,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              Icons.graphic_eq_rounded,
                              size:
                                  (isCompactWidescreenLayout ? 34 : 42) *
                                  desktopHeightScale,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          SizedBox(width: isCompactWidescreenLayout ? 12 : 18),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: desktopMetadataMaxWidth,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    _surahName(_selectedSurah),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedReciterName(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Surah $_selectedSurah',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: bottomBarCenterGap),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Choose Surah',
                              onPressed: _openSurahPickerSheet,
                              icon: Icon(
                                Icons.queue_music_rounded,
                                size: actionIconSize,
                              ),
                            ),
                            speedButton,
                            downloadButton,
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
                      constraints: BoxConstraints(maxWidth: desktopCenterWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Shuffle',
                                onPressed: () {
                                  _safeSetState(() {
                                    _shuffleEnabled = !_shuffleEnabled;
                                  });
                                },
                                icon: const Icon(Icons.shuffle_rounded),
                                color: _shuffleEnabled
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Previous',
                                onPressed: _playPrevious,
                                icon: const Icon(Icons.skip_previous_rounded),
                                iconSize: playerControlIconSize,
                              ),
                              const SizedBox(width: 6),
                              buildPlayPauseButton(),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Next',
                                onPressed: _playNext,
                                icon: const Icon(Icons.skip_next_rounded),
                                iconSize: playerControlIconSize,
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Loop',
                                onPressed: () {
                                  _safeSetState(() {
                                    _loopEnabled = !_loopEnabled;
                                  });
                                },
                                icon: const Icon(Icons.repeat_rounded),
                                color: _loopEnabled
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
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
                              buildTimeLabel(
                                _duration,
                                textAlign: TextAlign.right,
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
        );

        final Widget foldableNowPlaying = Transform.translate(
          offset: Offset(0, -foldableRightPanelLift),
          child: Padding(
            padding: EdgeInsets.only(bottom: foldableRightPanelLift),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: artworkPanel,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                playbackPanel,
              ],
            ),
          ),
        );

        final Widget mobileNowPlaying = LayoutBuilder(
          builder: (BuildContext context, BoxConstraints bodyConstraints) {
            final double availableHeight = bodyConstraints.maxHeight;
            final double mobileArtSize = min(
              min(width - 56, 440),
              max(72.0, availableHeight - 350),
            );
            final double mobileGap = (availableHeight - mobileArtSize - 336)
                .clamp(4.0, 16.0)
                .toDouble();

            return Transform.translate(
              offset: const Offset(0, -12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Flexible(
                    fit: FlexFit.loose,
                    child: Center(
                      child: buildArtworkSquare(
                        panelArtSize: mobileArtSize,
                        panelIconSize: min(130, mobileArtSize * 0.42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  buildArtworkActions(),
                  SizedBox(height: mobileGap),
                  playbackPanel,
                ],
              ),
            );
          },
        );

        final Widget bodyContent = isDesktop
            ? LayoutBuilder(
                builder: (context, bodyConstraints) {
                  final double bottomBarEstimatedHeight =
                      desktopBottomBarMinHeight +
                      (desktopBottomBarVerticalPadding * 2);
                  final double availableArtworkHeight =
                      (bodyConstraints.maxHeight -
                              bottomBarEstimatedHeight -
                              28)
                          .clamp(72.0, double.infinity)
                          .toDouble();
                  final double fittedArtSize = min(
                    artSize,
                    availableArtworkHeight,
                  );
                  final double fittedArtIconSize = min(
                    170 * desktopHeightScale,
                    fittedArtSize * 0.38,
                  );

                  return Column(
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: buildArtworkSquare(
                              panelArtSize: fittedArtSize,
                              panelIconSize: fittedArtIconSize,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      desktopBottomBar,
                    ],
                  );
                },
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
