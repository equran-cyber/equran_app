import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/services.dart';

class AndroidAudioDisplayMode {
  // TODO: Re-enable only after the minimized-player low-refresh policy is
  // redesigned so the display mode cannot leak into app-wide navigation UI.
  static const bool _enableStaticMinimizedLowRefresh = false;
  static const double _systemFrameRate = 0.0;
  static const double _defaultLimitedProgressFrameRate = 30.0;
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
  static final Set<String> _lowRefreshBlockers = <String>{};
  static double _limitedProgressFrameRate = _defaultLimitedProgressFrameRate;
  static bool _limitedFrameRateEnabled = true;
  static bool _staticMinimizedRefreshWanted = false;
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
    unawaited(
      _applyPreferredFrameRate(_systemFrameRate, reason: 'user activity'),
    );
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

  static Future<void> setLimitedProgressFrameRate(double frameRate) async {
    if (!_isSupported) return;

    final double nextFrameRate = frameRate <= 0
        ? _defaultLimitedProgressFrameRate
        : frameRate;
    if (_limitedProgressFrameRate == nextFrameRate) return;

    _limitedProgressFrameRate = nextFrameRate;
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
    await _restoreStaticMinimizedRefreshIfEligible('suppression changed');
  }

  static Future<void> addLowRefreshBlocker(
    String blocker, {
    String reason = '',
  }) async {
    if (!_isSupported) return;

    final bool added = _lowRefreshBlockers.add(blocker);
    _debugLog(
      '${added ? "added" : "kept"} blocker "$blocker"'
      '${reason.isEmpty ? "" : " ($reason)"}',
    );
    await _applyPreferredFrameRate(
      _systemFrameRate,
      reason: reason.isEmpty ? 'blocker $blocker' : reason,
    );
  }

  static Future<void> removeLowRefreshBlocker(
    String blocker, {
    String reason = '',
  }) async {
    if (!_isSupported) return;

    final bool removed = _lowRefreshBlockers.remove(blocker);
    _debugLog(
      '${removed ? "removed" : "missing"} blocker "$blocker"'
      '${reason.isEmpty ? "" : " ($reason)"}',
    );
    await _reconcileFrameRatePolicy();
    await _restoreStaticMinimizedRefreshIfEligible(
      reason.isEmpty ? 'blocker removed' : reason,
    );
  }

  static Future<void> requestStaticMinimizedAudioRefreshRate({
    bool force = false,
  }) async {
    if (!_isSupported) return;
    _staticMinimizedRefreshWanted = true;
    if (!_enableStaticMinimizedLowRefresh) {
      _debugLog(
        'skipped static minimized refresh request; temporary flag disabled',
      );
      await _applyPreferredFrameRate(
        _systemFrameRate,
        reason: 'static minimized low refresh disabled',
      );
      return;
    }

    if (_lowRefreshBlockers.isNotEmpty || _lowFpsSuppressionCount > 0) {
      _debugLog(
        'blocked static minimized refresh request; '
        'blockers=${_blockerSummary()} suppression=$_lowFpsSuppressionCount',
      );
      await _applyPreferredFrameRate(
        _systemFrameRate,
        reason: 'static request blocked',
      );
      return;
    }
    if (_staticMinimizedRefreshRequested && !force) return;

    _idleTimer?.cancel();
    _idleTimer = null;
    _staticMinimizedRefreshRequested = true;
    _lastAppliedFrameRate = null;

    try {
      final Object? result = await _channel.invokeMethod<Object?>(
        'requestLowestRefreshRate',
      );
      _debugLog(
        'requested static minimized refresh $result; '
        'blockers=${_blockerSummary()}',
      );
    } catch (_) {
      // Some Android surfaces/devices ignore refresh-rate hints. Playback and
      // the static minimized UI should continue normally.
      _staticMinimizedRefreshRequested = false;
    }
  }

  static Future<void> clearStaticMinimizedAudioRefreshRate({
    bool force = false,
    bool clearWanted = true,
  }) async {
    if (!_isSupported) return;
    if (clearWanted) {
      _staticMinimizedRefreshWanted = false;
    }
    if (!_staticMinimizedRefreshRequested && !force) return;

    _staticMinimizedRefreshRequested = false;
    _lastAppliedFrameRate = null;

    try {
      await _channel.invokeMethod<void>('clearRefreshRatePreference');
      _debugLog('cleared static minimized refresh');
    } catch (_) {
      // Devices that ignore frame-rate hints should not affect playback.
    }
  }

  static bool get _shouldUseLimitedFrameRate {
    // Active progress UI should stay at the system refresh rate. The only
    // low-refresh path that remains eligible is the explicit static minimized
    // player request, which is guarded separately by blockers.
    return false;
  }

  static Future<void> _reconcileFrameRatePolicy() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    if (await _restoreStaticMinimizedRefreshIfEligible('reconcile')) {
      return;
    }

    // Audio playback is decoupled from refresh-rate hints. Active progress UI,
    // drawers, route transitions, and modals stay on Android's dynamic refresh
    // selection; only the static minimized player may request low refresh.
    if (!_shouldUseLimitedFrameRate) {
      await _applyPreferredFrameRate(
        _systemFrameRate,
        reason: 'limited refresh not eligible',
      );
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime lastActivity = _lastUserActivityAt ?? now;
    final Duration idleFor = now.difference(lastActivity);
    if (idleFor < _defaultIdleDelay) {
      _idleTimer = Timer(_defaultIdleDelay - idleFor, () {
        _handleIdleTimer(_defaultIdleDelay);
      });
      await _applyPreferredFrameRate(
        _systemFrameRate,
        reason: 'recent user activity',
      );
      return;
    }

    await _applyPreferredFrameRate(
      _limitedProgressFrameRate,
      reason: 'audio progress idle',
    );
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
    unawaited(
      _applyPreferredFrameRate(
        _limitedProgressFrameRate,
        reason: 'idle timer',
      ),
    );
  }

  static Future<void> _applyPreferredFrameRate(
    double frameRate, {
    required String reason,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_staticMinimizedRefreshRequested) {
      await clearStaticMinimizedAudioRefreshRate(clearWanted: false);
    }
    if (_lastAppliedFrameRate == frameRate) return;

    _lastAppliedFrameRate = frameRate;
    _debugLog(
      frameRate <= 0
          ? 'clearing preferred frame rate ($reason); '
                'blockers=${_blockerSummary()}'
          : 'requesting ${frameRate}Hz ($reason); '
                'blockers=${_blockerSummary()}',
    );

    try {
      await _channel.invokeMethod<void>('setPreferredFrameRate', <String, num>{
        'frameRate': frameRate,
      });
    } catch (_) {
      // Devices that ignore frame-rate hints should not affect playback.
      _lastAppliedFrameRate = null;
    }
  }

  static String _blockerSummary() {
    if (_lowRefreshBlockers.isEmpty) return 'none';
    return _lowRefreshBlockers.join(',');
  }

  static void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('AndroidAudioDisplayMode: $message');
  }

  static Future<bool> _restoreStaticMinimizedRefreshIfEligible(
    String reason,
  ) async {
    if (!_staticMinimizedRefreshWanted ||
        !_enableStaticMinimizedLowRefresh ||
        _staticMinimizedRefreshRequested ||
        _lowRefreshBlockers.isNotEmpty ||
        _lowFpsSuppressionCount > 0) {
      return false;
    }

    _debugLog('restoring static minimized refresh after $reason');
    await requestStaticMinimizedAudioRefreshRate(force: true);
    return true;
  }
}
