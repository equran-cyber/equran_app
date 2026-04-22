import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class AndroidAudioDisplayMode {
  static const double _systemFrameRate = 0.0;
  static const double _idleAudioFrameRate = 30.0;
  static const Duration _defaultIdleDelay = Duration(milliseconds: 500);
  static const MethodChannel _channel = MethodChannel(
    'com.app.equran/read_page',
  );

  static bool _audioPlaybackActive = false;
  static double? _lastAppliedFrameRate;
  static Timer? _idleTimer;
  static DateTime? _lastUserActivityAt;
  static int _lowFpsSuppressionCount = 0;

  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> setAudioPlaybackActive(bool active) async {
    if (!_isSupported) return;
    if (_audioPlaybackActive == active) return;

    _audioPlaybackActive = active;
    _idleTimer?.cancel();
    _idleTimer = null;
    _lastUserActivityAt = null;

    if (!active) {
      await _applyPreferredFrameRate(_systemFrameRate);
      return;
    }

    await _applyPreferredFrameRate(_systemFrameRate);
    if (_lowFpsSuppressionCount > 0) return;
    _scheduleIdleFrameRate();
  }

  static void notifyUserActivity({Duration idleDelay = _defaultIdleDelay}) {
    if (!_isSupported || !_audioPlaybackActive) return;

    _lastUserActivityAt = DateTime.now();
    unawaited(_applyPreferredFrameRate(_systemFrameRate));
    if (_lowFpsSuppressionCount > 0) return;
    _idleTimer ??= Timer(idleDelay, () => _handleIdleTimer(idleDelay));
  }

  static Future<void> setLowFpsSuppressed(bool suppressed) async {
    if (!_isSupported) return;
    if (suppressed) {
      _lowFpsSuppressionCount++;
      _idleTimer?.cancel();
      _idleTimer = null;
      await _applyPreferredFrameRate(_systemFrameRate);
      return;
    }

    if (_lowFpsSuppressionCount > 0) {
      _lowFpsSuppressionCount--;
    }
    if (_lowFpsSuppressionCount == 0 && _audioPlaybackActive) {
      _scheduleIdleFrameRate();
    }
  }

  static void _scheduleIdleFrameRate() {
    _lastUserActivityAt = DateTime.now();
    _idleTimer = Timer(
      _defaultIdleDelay,
      () => _handleIdleTimer(_defaultIdleDelay),
    );
  }

  static void _handleIdleTimer(Duration idleDelay) {
    if (!_audioPlaybackActive) {
      _idleTimer = null;
      return;
    }
    if (_lowFpsSuppressionCount > 0) {
      _idleTimer = null;
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime lastActivity = _lastUserActivityAt ?? now;
    final Duration idleFor = now.difference(lastActivity);
    if (idleFor < idleDelay) {
      _idleTimer = Timer(idleDelay - idleFor, () {
        _handleIdleTimer(idleDelay);
      });
      return;
    }

    _idleTimer = null;
    unawaited(_applyPreferredFrameRate(_idleAudioFrameRate));
  }

  static Future<void> _applyPreferredFrameRate(double frameRate) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_lastAppliedFrameRate == frameRate) return;

    _lastAppliedFrameRate = frameRate;

    try {
      await _channel.invokeMethod<void>('setPreferredFrameRate', <String, num>{
        'frameRate': frameRate,
      });
    } catch (_) {
      // Devices that ignore frame-rate hints should not affect playback.
      _lastAppliedFrameRate = null;
    }
  }
}
