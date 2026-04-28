import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';

class AndroidAudioDisplayMode {
  static const double _systemFrameRate = 0.0;
  static const double _limitedProgressFrameRate = 30.0;
  static const Duration _defaultIdleDelay = Duration(milliseconds: 500);
  static const MethodChannel _channel = MethodChannel(
    'com.app.equran/read_page',
  );

  static bool _audioPlaybackActive = false;
  static bool _visualProgressActive = false;
  static double? _lastAppliedFrameRate;
  static Timer? _idleTimer;
  static DateTime? _lastUserActivityAt;
  static int _lowFpsSuppressionCount = 0;
  static bool _limitedFrameRateEnabled = true;
  static bool _staticMinimizedRefreshRequested = false;

  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> setAudioPlaybackActive(bool active) async {
    if (!_isSupported) return;
    if (_audioPlaybackActive == active) return;

    _audioPlaybackActive = active;
    if (active) _lastUserActivityAt = DateTime.now();
    await _reconcileFrameRatePolicy();
  }

  static Future<void> setVisualProgressActive(bool active) async {
    if (!_isSupported) return;
    if (_visualProgressActive == active) return;

    _visualProgressActive = active;
    if (active) _lastUserActivityAt = DateTime.now();
    await _reconcileFrameRatePolicy();
  }

  static void notifyUserActivity({Duration idleDelay = _defaultIdleDelay}) {
    if (!_isSupported) return;

    _lastUserActivityAt = DateTime.now();
    unawaited(_applyPreferredFrameRate(_systemFrameRate));
    if (!_shouldUseLimitedFrameRate) return;

    _idleTimer?.cancel();
    _idleTimer = Timer(idleDelay, () => _handleIdleTimer(idleDelay));
  }

  static Future<void> setIdleAudioFrameRateEnabled(bool enabled) async {
    if (!_isSupported) return;
    if (_limitedFrameRateEnabled == enabled) return;

    _limitedFrameRateEnabled = enabled;
    await _reconcileFrameRatePolicy();
  }

  static Future<void> setLowFpsSuppressed(bool suppressed) async {
    if (!_isSupported) return;
    if (suppressed) {
      _lowFpsSuppressionCount++;
    } else if (_lowFpsSuppressionCount > 0) {
      _lowFpsSuppressionCount--;
    }

    await _reconcileFrameRatePolicy();
  }

  static Future<void> requestStaticMinimizedAudioRefreshRate({
    bool force = false,
  }) async {
    if (!_isSupported) return;
    if (_staticMinimizedRefreshRequested && !force) return;

    _idleTimer?.cancel();
    _idleTimer = null;
    _staticMinimizedRefreshRequested = true;
    _lastAppliedFrameRate = null;

    try {
      final Object? result = await _channel.invokeMethod<Object?>(
        'requestLowestRefreshRate',
      );
      debugPrint(
        'AndroidAudioDisplayMode: requested static minimized refresh $result',
      );
    } catch (_) {
      // Some Android surfaces/devices ignore refresh-rate hints. Playback and
      // the static minimized UI should continue normally.
      _staticMinimizedRefreshRequested = false;
    }
  }

  static Future<void> clearStaticMinimizedAudioRefreshRate({
    bool force = false,
  }) async {
    if (!_isSupported) return;
    if (!_staticMinimizedRefreshRequested && !force) return;

    _staticMinimizedRefreshRequested = false;
    _lastAppliedFrameRate = null;

    try {
      await _channel.invokeMethod<void>('clearRefreshRatePreference');
      debugPrint('AndroidAudioDisplayMode: cleared static minimized refresh');
    } catch (_) {
      // Devices that ignore frame-rate hints should not affect playback.
    }
  }

  static bool get _shouldUseLimitedFrameRate {
    return _audioPlaybackActive &&
        _visualProgressActive &&
        _lowFpsSuppressionCount == 0 &&
        _limitedFrameRateEnabled;
  }

  static Future<void> _reconcileFrameRatePolicy() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    // Audio playback is decoupled from refresh-rate hints. We only hold a
    // low frame-rate hint while a visible progress control is moving; hidden
    // players, minimized players, modals, and idle non-audio screens return to
    // Android's dynamic refresh-rate selection.
    if (!_shouldUseLimitedFrameRate) {
      await _applyPreferredFrameRate(_systemFrameRate);
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime lastActivity = _lastUserActivityAt ?? now;
    final Duration idleFor = now.difference(lastActivity);
    if (idleFor < _defaultIdleDelay) {
      _idleTimer = Timer(_defaultIdleDelay - idleFor, () {
        _handleIdleTimer(_defaultIdleDelay);
      });
      await _applyPreferredFrameRate(_systemFrameRate);
      return;
    }

    await _applyPreferredFrameRate(_limitedProgressFrameRate);
  }

  static void _handleIdleTimer(Duration idleDelay) {
    if (!_shouldUseLimitedFrameRate) {
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
    unawaited(_applyPreferredFrameRate(_limitedProgressFrameRate));
  }

  static Future<void> _applyPreferredFrameRate(double frameRate) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_staticMinimizedRefreshRequested) {
      await clearStaticMinimizedAudioRefreshRate();
    }
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
