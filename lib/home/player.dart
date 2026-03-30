import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
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
  final ja.AudioPlayer _justAudio = ja.AudioPlayer();
  final ap.AudioPlayer _linuxAudio = ap.AudioPlayer();
  final Random _random = Random();

  late final bool _useLinuxFallback;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<ja.PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _linuxPositionSubscription;
  StreamSubscription<Duration>? _linuxDurationSubscription;
  StreamSubscription<ap.PlayerState>? _linuxStateSubscription;
  StreamSubscription<void>? _linuxCompleteSubscription;

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

  double _playbackRate = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _useLinuxFallback = !kIsWeb && Platform.isLinux;

    final dynamic rate = SettingsDB().get("playbackRate", defaultValue: 1.0);
    if (rate is num) {
      _playbackRate = rate.toDouble().clamp(0.5, 2.0);
    }

    _bindAudioListeners();
    _refreshDownloadState();
  }

  void _bindAudioListeners() {
    if (_useLinuxFallback) {
      _linuxPositionSubscription =
          _linuxAudio.onPositionChanged.listen((position) {
        _safeSetState(() {
          _position = position;
        });
      });

      _linuxDurationSubscription =
          _linuxAudio.onDurationChanged.listen((duration) {
        _safeSetState(() {
          _duration = duration;
        });
      });

      _linuxStateSubscription =
          _linuxAudio.onPlayerStateChanged.listen((state) {
        _safeSetState(() {
          _isPlaying = state == ap.PlayerState.playing;
          _isPaused = state == ap.PlayerState.paused;
          if (_isPlaying || _isPaused || state == ap.PlayerState.stopped) {
            _isLoading = false;
          }
        });
      });

      _linuxCompleteSubscription = _linuxAudio.onPlayerComplete.listen((_) async {
        await _handleTrackComplete();
      });
      return;
    }

    _positionSubscription = _justAudio.positionStream.listen((position) {
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
        if (_isPlaying ||
            state.processingState == ja.ProcessingState.ready ||
            state.processingState == ja.ProcessingState.completed) {
          _isLoading = false;
        }
      });

      if (state.processingState == ja.ProcessingState.completed) {
        await _handleTrackComplete();
      }
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

  String _surahFileName(int surah) => '${surah.toString().padLeft(3, '0')}.mp3';

  String _surahStreamUrl(int surah) => quran.getAudioURLBySurah(surah, reciter: quran.Reciter.arAlafasy);

  String _time(Duration value) {
    final int totalHours = value.inHours;
    final String minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (totalHours > 0) {
      final String hours = totalHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
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

  Future<Directory> _audioDirectory() async {
    final Directory baseDir = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${baseDir.path}/surah_audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _surahFile(int surah) async {
    final Directory dir = await _audioDirectory();
    return File('${dir.path}/${_surahFileName(surah)}');
  }

  Future<bool> _hasOfflineFile(int surah) async {
    final File file = await _surahFile(surah);
    return file.existsSync();
  }

  Future<void> _refreshDownloadState() async {
    final bool isDownloaded = await _hasOfflineFile(_selectedSurah);
    _safeSetState(() {
      _isDownloaded = isDownloaded;
    });
  }

  Future<void> _setPlaybackRate(double value) async {
    final double rate = _useLinuxFallback ? 1.0 : value.clamp(0.5, 2.0);
    _safeSetState(() {
      _playbackRate = rate;
    });
    await SettingsDB().put("playbackRate", rate);

    if (_useLinuxFallback) {
      await _linuxAudio.setPlaybackRate(rate);
    } else {
      await _justAudio.setSpeed(rate);
    }
  }

  Future<void> _startTrack({
    required int surah,
    required bool playOffline,
  }) async {
    if (_useLinuxFallback) {
      await _linuxAudio.stop();
      _safeSetState(() {
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      if (playOffline) {
        final File file = await _surahFile(surah);
        await _linuxAudio.play(ap.DeviceFileSource(file.path));
      } else {
        await _linuxAudio.play(ap.UrlSource(_surahStreamUrl(surah)));
      }
      await _linuxAudio.setPlaybackRate(_playbackRate);
      return;
    }

    final Uri sourceUri;
    if (playOffline) {
      final File file = await _surahFile(surah);
      sourceUri = Uri.file(file.path);
    } else {
      sourceUri = Uri.parse(_surahStreamUrl(surah));
    }

    await _justAudio.setAudioSource(
      ja.AudioSource.uri(
        sourceUri,
        tag: MediaItem(
          id: 'surah-$surah-${playOffline ? "offline" : "stream"}',
          album: 'eQuran',
          title: _surahName(surah),
          artist: playOffline ? 'Offline MP3' : 'Streaming',
          displayDescription: 'Surah $surah',
        ),
      ),
    );
    await _justAudio.setSpeed(_playbackRate);
    unawaited(_justAudio.play());
  }

  Future<void> _resumeCurrentTrack() async {
    if (_useLinuxFallback) {
      await _linuxAudio.resume();
      await _linuxAudio.setPlaybackRate(_playbackRate);
    } else {
      unawaited(_justAudio.play());
      await _justAudio.setSpeed(_playbackRate);
    }
  }

  Future<void> _pauseCurrentTrack() async {
    if (_useLinuxFallback) {
      await _linuxAudio.pause();
    } else {
      await _justAudio.pause();
    }
  }

  Future<void> _stopCurrentTrack() async {
    if (_useLinuxFallback) {
      await _linuxAudio.stop();
    } else {
      await _justAudio.stop();
    }
  }

  Future<void> _seekCurrentTrack(Duration position) async {
    if (_useLinuxFallback) {
      await _linuxAudio.seek(position);
    } else {
      await _justAudio.seek(position);
    }
  }

  Future<void> _playSurah(int surah, {bool forceRestart = false}) async {
    final bool shouldPlayOffline = await _hasOfflineFile(surah);

    _safeSetState(() {
      _selectedSurah = surah;
      _isDownloaded = shouldPlayOffline;
      _playingFromOffline = shouldPlayOffline;
      _isLoading = true;
    });

    try {
      final bool sameTrack = _loadedSurah == surah &&
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
    } finally {
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

  Future<void> _selectSurah(int? surah) async {
    if (surah == null) return;
    await _playSurah(surah, forceRestart: true);
  }

  Widget _buildSurahSelectionList({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool closeOnSelect,
  }) {
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
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
            borderRadius: BorderRadius.circular(14),
          ),
          selectedColor: colorScheme.onSurface,
          textColor: colorScheme.onSurface,
          iconColor: colorScheme.onSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colorScheme.surfaceContainerHigh.withOpacity(0.78),
              colorScheme.surfaceContainer.withOpacity(0.66),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.55),
          ),
        ),
        child: Column(
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
              color: colorScheme.outlineVariant.withOpacity(0.35),
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
      ),
    );
  }

  Future<void> _openSurahPickerSheet() async {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int? selectedSurah = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final double maxHeight = min(
          MediaQuery.sizeOf(context).height * 0.72,
          620,
        );
        return SafeArea(
          child: Material(
            color: colorScheme.surfaceContainer,
            child: SizedBox(
              height: maxHeight,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      final http.Response response =
          await http.get(Uri.parse(_surahStreamUrl(_selectedSurah)));
      if (response.statusCode != 200) {
        throw Exception('Download failed');
      }

      final File file = await _surahFile(_selectedSurah);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      await _refreshDownloadState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${_surahName(_selectedSurah)}')),
        );
      }
    } catch (_) {
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
    final File file = await _surahFile(_selectedSurah);
    if (!file.existsSync()) return;

    try {
      await file.delete();

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
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _linuxPositionSubscription?.cancel();
    _linuxDurationSubscription?.cancel();
    _linuxStateSubscription?.cancel();
    _linuxCompleteSubscription?.cancel();

    _justAudio.dispose();
    _linuxAudio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final List<double> playbackRates = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isFoldableLayout = width >= 720 && width < 1100;
        final bool isDesktop = width >= 1100;
        final double maxContentWidth = isDesktop
            ? 980
            : isFoldableLayout
                ? min(width, 1000)
                : 560;
        final double artSize = isDesktop
            ? 520
            : isFoldableLayout
                ? min(width * 0.42, 360)
                : min(width - 56, 440);

        final header = Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 24 : 16),
          child: Row(
            children: <Widget>[
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
              Expanded(
                child: Text(
                  _surahName(_selectedSurah),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        );

        final Widget speedButton = MenuAnchor(
          style: MenuStyle(
            backgroundColor: MaterialStatePropertyAll(colorScheme.surfaceContainer),
            surfaceTintColor: MaterialStatePropertyAll(colorScheme.surfaceTint),
            elevation: const MaterialStatePropertyAll(6),
            side: MaterialStatePropertyAll(
              BorderSide(color: colorScheme.outlineVariant),
            ),
            shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            padding: const MaterialStatePropertyAll(
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
                onPressed: (!_useLinuxFallback || rate == 1.0)
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
            icon: const Icon(Icons.speed_rounded),
          ),
        );

        final Widget downloadButton = _isDownloaded
            ? IconButton(
                tooltip: 'Delete downloaded MP3',
                onPressed: _confirmDeleteSurahDownload,
                icon: Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                ),
              )
            : IconButton(
                tooltip: 'Download MP3',
                onPressed: _isDownloading ? null : _downloadSurah,
                icon: _isDownloading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
              );

        final nowPlaying = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
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
                      color: colorScheme.shadow.withOpacity(0.18),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: isDesktop ? 170 : 130,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
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
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
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
                      Text(
                        'Surah $_selectedSurah • ${_isDownloaded ? "Offline MP3" : "Streaming"}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(value: progress, onChanged: (value) => _seek(value)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _time(_position),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  _time(_duration),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
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
                  iconSize: 34,
                ),
                FilledButton(
                  onPressed: _togglePlayPause,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                        ),
                ),
                IconButton(
                  tooltip: 'Next',
                  onPressed: _playNext,
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 34,
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

        final Widget bodyContent = isFoldableLayout
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
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: nowPlaying,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: nowPlaying,
              );

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                colorScheme.primaryContainer.withOpacity(0.60),
                colorScheme.tertiaryContainer.withOpacity(0.35),
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
        );
      },
    );
  }
}
