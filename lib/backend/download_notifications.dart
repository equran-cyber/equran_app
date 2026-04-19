import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class DownloadNotifications {
  static const MethodChannel _channel = MethodChannel(
    'com.app.equran/read_page',
  );

  static int notificationId(String key) {
    return 10000 + key.hashCode.abs() % 80000;
  }

  static Future<void> progress({
    required int id,
    required String title,
    required double? progress,
  }) async {
    if (!_isSupported) return;

    final int percentage = progress == null
        ? 0
        : (progress.clamp(0.0, 1.0) * 100).round();
    if (percentage >= 100 && progress != null) {
      await cancel(id);
      return;
    }

    await _invoke('showDownloadProgress', <String, Object>{
      'id': id,
      'title': title,
      'progress': percentage,
      'max': 100,
      'indeterminate': progress == null,
    });
  }

  static Future<void> complete({required int id, required String title}) async {
    if (!_isSupported) return;
    await cancel(id);
  }

  static Future<void> fail({required int id, required String title}) async {
    if (!_isSupported) return;
    await _invoke('failDownload', <String, Object>{'id': id, 'title': title});
  }

  static Future<void> cancel(int id) async {
    if (!_isSupported) return;
    await _invoke('cancelDownloadNotification', <String, Object>{'id': id});
  }

  static bool get _isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> _invoke(
    String method,
    Map<String, Object> arguments,
  ) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (_) {
      // Downloads must not fail if notification access is unavailable.
    }
  }
}

class DownloadProgress {
  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.completedFiles,
    required this.totalFiles,
  });

  final int receivedBytes;
  final int? totalBytes;
  final int completedFiles;
  final int totalFiles;

  double? get fraction {
    final int? total = totalBytes;
    if (total != null && total > 0) {
      final double fileFraction = receivedBytes / total;
      return ((completedFiles + fileFraction.clamp(0.0, 1.0)) / totalFiles)
          .clamp(0.0, 1.0);
    }
    if (totalFiles > 0) {
      if (completedFiles == 0) return null;
      return (completedFiles / totalFiles).clamp(0.0, 1.0);
    }
    return null;
  }

  double? get fileFraction {
    final int? total = totalBytes;
    if (total == null || total <= 0) return null;
    return min(1.0, max(0.0, receivedBytes / total));
  }
}
