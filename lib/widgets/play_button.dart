import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:equran/backend/library.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:http/http.dart' as http;

class PlayButton extends StatefulWidget {
  final Future<String> url;

  const PlayButton({super.key, required this.url});

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  static const int _maxCachedAyahs = 5;
  static final LinkedHashMap<String, Uint8List> _audioCache =
      LinkedHashMap<String, Uint8List>();

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completeSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;

  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (_audioPlayer.state == PlayerState.playing) {
        _updateProgress(position);
      }
    });

    // When the audio has finished playing this is what to do...
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      _safeSetState(() {
        _isPlaying = false;
        _progress = 0.0;
      });
    });

    // Listen for errors
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped && _isPlaying) {
        _safeSetState(() {
          _hasError = true;
          _isPlaying = false;
          _isLoading = false;
        });
      }
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _updateProgress(Duration position) async {
    Duration duration = await _audioPlayer.getDuration() ?? Duration.zero;
    if (!mounted) return;
    if (duration.inMilliseconds > 0) {
      _safeSetState(() {
        _progress = position.inMilliseconds / duration.inMilliseconds;
      });
    }
  }

  Uint8List? _getCachedAudio(String url) {
    final Uint8List? cached = _audioCache.remove(url);
    if (cached == null) {
      return null;
    }

    _audioCache[url] = cached;
    return cached;
  }

  void _cacheAudio(String url, Uint8List bytes) {
    _audioCache.remove(url);
    _audioCache[url] = bytes;

    while (_audioCache.length > _maxCachedAyahs) {
      _audioCache.remove(_audioCache.keys.first);
    }
  }

  Future<Uint8List> _downloadAudioBytes(String url) async {
    final http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load audio: ${response.statusCode}');
    }

    return Uint8List.fromList(response.bodyBytes);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _stateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    final Uint8List? cachedAudio = _getCachedAudio(url);
    if (cachedAudio != null) {
      await _audioPlayer.play(BytesSource(cachedAudio));
      return;
    }

    try {
      final Uint8List bytes = await _downloadAudioBytes(url);
      _cacheAudio(url, bytes);
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('Error loading audio: $e');
      if (!kIsWeb) {
        rethrow;
      }

      final proxiedUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
      await _audioPlayer.play(UrlSource(proxiedUrl));
    }
  }

  double _playbackRate() {
    final dynamic value = SettingsDB().get("playbackRate", defaultValue: 1.0);
    if (value is num) {
      return value.toDouble().clamp(0.5, 2.0);
    }
    return 1.0;
  }

  void _togglePlayPause() async {
    _safeSetState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        _safeSetState(() {
          _isLoading = false;
          _isPlaying = false;
        });
      } else {
        final String resolvedUrl = await widget.url;
        if (resolvedUrl.isEmpty) {
          throw Exception('Audio URL is empty.');
        }

        final double rate = _playbackRate();
        await _audioPlayer.setPlaybackRate(rate);
        if (_audioPlayer.state == PlayerState.paused) {
          await _audioPlayer.resume();
        } else {
          await _playAudio(resolvedUrl);
        }
        // Re-apply because some platforms reset rate when a source is (re)started.
        await _audioPlayer.setPlaybackRate(rate);

        _safeSetState(() {
          _isLoading = false;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _safeSetState(() {
        _isLoading = false;
        _isPlaying = false;
        _hasError = true;
      });

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(kIsWeb
                ? 'Unable to play audio on web. Try downloading the app for better experience.'
                : 'Failed to play audio. Please check your internet connection.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isPlaying)
          CircularPercentIndicator(
            radius: 20.0,
            progressColor: Theme.of(context).colorScheme.primary,
            lineWidth: 3.5,
            percent: _progress,
          ),
        IconButton(
          onPressed: _togglePlayPause,
          icon: _isLoading
              ? const SizedBox(
            width: 29,
            height: 29,
            child: CircularProgressIndicator(
              strokeWidth: 1,
            ),
          )
              : Icon(
            _hasError
                ? Icons.error_outline_rounded
                : !_isPlaying
                ? Icons.play_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            size: 29,
            color: _hasError ? Colors.red : null,
          ),
        )
      ],
    );
  }
}
