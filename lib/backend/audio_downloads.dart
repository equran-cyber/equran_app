import 'dart:io';
import 'dart:math';

import 'package:equran/backend/download_notifications.dart';
import 'package:equran/backend/quran_stream_url.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;

typedef AudioDownloadProgressCallback =
    void Function(DownloadProgress progress);

class AudioDownloadEntry {
  const AudioDownloadEntry({
    required this.file,
    required this.type,
    required this.reciterCode,
    required this.surah,
    required this.sizeBytes,
    this.ayah,
    this.additionalFiles = const <File>[],
  });

  final File file;
  final AudioDownloadType type;
  final String reciterCode;
  final int surah;
  final int? ayah;
  final int sizeBytes;
  final List<File> additionalFiles;

  String get title => type == AudioDownloadType.surah
      ? quran.getSurahName(surah)
      : type == AudioDownloadType.ayahSurah
      ? '${quran.getSurahName(surah)} • All Ayahs'
      : '${quran.getSurahName(surah)} • Ayah $ayah';

  String get subtitle => type == AudioDownloadType.surah
      ? 'Surah ${surah.toString().padLeft(3, '0')}'
      : type == AudioDownloadType.ayahSurah
      ? 'Surah $surah, ${quran.getVerseCount(surah)} ayahs'
      : 'Surah $surah, Ayah $ayah';

  int get ayahCount => type == AudioDownloadType.surah
      ? 0
      : type == AudioDownloadType.ayahSurah
      ? quran.getVerseCount(surah)
      : 1;

  List<File> get files => <File>[file, ...additionalFiles];
}

enum AudioDownloadType { surah, ayah, ayahSurah }

class AudioDownloadsSummary {
  const AudioDownloadsSummary({
    required this.surahDownloads,
    required this.ayahDownloads,
  });

  final List<AudioDownloadEntry> surahDownloads;
  final List<AudioDownloadEntry> ayahDownloads;

  List<AudioDownloadEntry> get allDownloads => <AudioDownloadEntry>[
    ...surahDownloads,
    ...ayahDownloads,
  ];

  int get totalSizeBytes =>
      allDownloads.fold<int>(0, (total, entry) => total + entry.sizeBytes);

  int get surahCount => surahDownloads.length;

  int get ayahCount =>
      ayahDownloads.fold<int>(0, (total, entry) => total + entry.ayahCount);
}

class AudioDownloadService {
  static const String _surahDirectoryName = 'surah_audio';
  static const String _ayahDirectoryName = 'ayah_audio';
  static final Map<String, Future<List<File>>> _surahAyahDownloads =
      <String, Future<List<File>>>{};

  Future<Directory> _audioDirectory(String directoryName) async {
    final Directory baseDir = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${baseDir.path}/$directoryName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> surahDirectory() => _audioDirectory(_surahDirectoryName);

  Future<Directory> ayahDirectory() => _audioDirectory(_ayahDirectoryName);

  String _reciterCode() => QuranAudioService().selectedReciter.code;

  String surahFileName(int surah) {
    return '${_reciterCode()}_${surah.toString().padLeft(3, '0')}.mp3';
  }

  String ayahFileName(int surah, int ayah) {
    return '${_reciterCode()}_${surah.toString().padLeft(3, '0')}_${ayah.toString().padLeft(3, '0')}.mp3';
  }

  Future<File> surahFile(int surah) async {
    final Directory dir = await surahDirectory();
    return File('${dir.path}/${surahFileName(surah)}');
  }

  Future<File> ayahFile(int surah, int ayah) async {
    final Directory dir = await ayahDirectory();
    return File('${dir.path}/${ayahFileName(surah, ayah)}');
  }

  Future<bool> hasSurah(int surah) async {
    final File file = await surahFile(surah);
    return _isCompleteDownload(file);
  }

  Future<bool> hasAyah(int surah, int ayah) async {
    final File file = await ayahFile(surah, ayah);
    return _isCompleteDownload(file);
  }

  bool isSurahAyahsDownloadInProgress(int surah) {
    return _surahAyahDownloads.containsKey('${_reciterCode()}-$surah');
  }

  Future<File> downloadSurah(
    int surah, {
    AudioDownloadProgressCallback? onProgress,
  }) async {
    final String url = await QuranAudioService().getSurahUrl(surah);
    final File file = await surahFile(surah);
    await _downloadToFile(
      url,
      file,
      onProgress: onProgress == null
          ? null
          : (receivedBytes, totalBytes) => onProgress(
              DownloadProgress(
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
                completedFiles: 0,
                totalFiles: 1,
              ),
            ),
    );
    return file;
  }

  Future<File> downloadAyah(
    int surah,
    int ayah, {
    AudioDownloadProgressCallback? onProgress,
  }) async {
    final String url = await QuranAudioService().getAyahUrl(surah, ayah);
    final File file = await ayahFile(surah, ayah);
    await _downloadToFile(
      url,
      file,
      onProgress: onProgress == null
          ? null
          : (receivedBytes, totalBytes) => onProgress(
              DownloadProgress(
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
                completedFiles: 0,
                totalFiles: 1,
              ),
            ),
    );
    return file;
  }

  Future<List<File>> downloadSurahAyahs(
    int surah, {
    AudioDownloadProgressCallback? onProgress,
  }) async {
    final String downloadKey = '${_reciterCode()}-$surah';
    final Future<List<File>>? activeDownload = _surahAyahDownloads[downloadKey];
    if (activeDownload != null) {
      return activeDownload;
    }

    final Future<List<File>> download = _downloadMissingSurahAyahs(
      surah,
      onProgress: onProgress,
    );
    _surahAyahDownloads[downloadKey] = download;
    void clearActiveDownload() {
      if (identical(_surahAyahDownloads[downloadKey], download)) {
        _surahAyahDownloads.remove(downloadKey);
      }
    }

    download.then<void>(
      (_) => clearActiveDownload(),
      onError: (_, _) => clearActiveDownload(),
    );
    return download;
  }

  Future<List<File>> _downloadMissingSurahAyahs(
    int surah, {
    AudioDownloadProgressCallback? onProgress,
  }) async {
    final int totalAyahs = quran.getVerseCount(surah);
    final List<File?> files = List<File?>.filled(totalAyahs, null);
    final List<({int ayah, File file})> pendingDownloads =
        <({int ayah, File file})>[];
    final Map<int, double> fileFractions = <int, double>{};

    for (int ayah = 1; ayah <= totalAyahs; ayah++) {
      final File file = await ayahFile(surah, ayah);
      if (_isCompleteDownload(file)) {
        files[ayah - 1] = file;
        continue;
      }

      pendingDownloads.add((ayah: ayah, file: file));
      fileFractions[ayah] = 0.0;
    }

    final int totalPendingFiles = pendingDownloads.length;
    if (totalPendingFiles == 0) {
      return files.whereType<File>().toList(growable: false);
    }

    int nextIndex = 0;
    final int workerCount = min(6, totalPendingFiles);
    Future<void> worker() async {
      while (true) {
        final int taskIndex = nextIndex++;
        if (taskIndex >= pendingDownloads.length) return;

        final task = pendingDownloads[taskIndex];
        final String url = await QuranAudioService().getAyahUrl(
          surah,
          task.ayah,
        );
        await _downloadToFile(
          url,
          task.file,
          onProgress: (receivedBytes, totalBytes) {
            if (totalBytes != null && totalBytes > 0) {
              fileFractions[task.ayah] = (receivedBytes / totalBytes).clamp(
                0.0,
                1.0,
              );
              _reportAggregateAyahProgress(
                onProgress: onProgress,
                fileFractions: fileFractions,
                totalFiles: totalPendingFiles,
              );
            }
          },
        );
        files[task.ayah - 1] = task.file;
        fileFractions[task.ayah] = 1.0;
        _reportAggregateAyahProgress(
          onProgress: onProgress,
          fileFractions: fileFractions,
          totalFiles: totalPendingFiles,
        );
      }
    }

    await Future.wait<void>(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );

    return files.whereType<File>().toList(growable: false);
  }

  void _reportAggregateAyahProgress({
    required AudioDownloadProgressCallback? onProgress,
    required Map<int, double> fileFractions,
    required int totalFiles,
  }) {
    if (onProgress == null || totalFiles <= 0) return;

    final double completedFraction =
        fileFractions.values.fold<double>(0.0, (sum, value) => sum + value) /
        totalFiles;
    const int progressUnits = 1000000;
    onProgress(
      DownloadProgress(
        receivedBytes: (completedFraction * progressUnits).round(),
        totalBytes: progressUnits,
        completedFiles: 0,
        totalFiles: 1,
      ),
    );
  }

  Future<void> _downloadToFile(
    String url,
    File file, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final Uri uri = Uri.parse(url);
    final File partialFile = File('${file.path}.part');
    final http.Client client = http.Client();
    try {
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      final http.StreamedResponse response = await client.send(
        http.Request('GET', uri),
      );
      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      final int? totalBytes = response.contentLength;
      int receivedBytes = 0;
      final IOSink sink = partialFile.openWrite();
      try {
        await for (final List<int> chunk in response.stream) {
          receivedBytes += chunk.length;
          sink.add(chunk);
          onProgress?.call(receivedBytes, totalBytes);
        }
      } finally {
        await sink.close();
      }
      if (await file.exists()) {
        await file.delete();
      }
      await partialFile.rename(file.path);
    } catch (_) {
      if (partialFile.existsSync()) {
        await partialFile.delete();
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> deleteSurah(int surah) async {
    final File file = await surahFile(surah);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> deleteAyah(int surah, int ayah) async {
    final File file = await ayahFile(surah, ayah);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> deleteEntry(AudioDownloadEntry entry) async {
    if (entry.file.existsSync()) {
      await entry.file.delete();
    }
    for (final File file in entry.additionalFiles) {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Future<void> clearAll() async {
    final AudioDownloadsSummary downloadsSummary = await summary();
    for (final AudioDownloadEntry entry in downloadsSummary.allDownloads) {
      await deleteEntry(entry);
    }
  }

  Future<AudioDownloadsSummary> summary() async {
    final List<AudioDownloadEntry> surahs = await _scanSurahs();
    final List<AudioDownloadEntry> ayahs = _bundleCompleteAyahSurahs(
      await _scanAyahs(),
    );
    surahs.sort(_compareEntries);
    ayahs.sort(_compareEntries);
    return AudioDownloadsSummary(surahDownloads: surahs, ayahDownloads: ayahs);
  }

  int _compareEntries(AudioDownloadEntry a, AudioDownloadEntry b) {
    final int surahCompare = a.surah.compareTo(b.surah);
    if (surahCompare != 0) return surahCompare;
    return (a.ayah ?? 0).compareTo(b.ayah ?? 0);
  }

  Future<List<AudioDownloadEntry>> _scanSurahs() async {
    final Directory dir = await surahDirectory();
    final RegExp pattern = RegExp(r'^(.+)_(\d{3})\.mp3$');
    final List<AudioDownloadEntry> entries = <AudioDownloadEntry>[];

    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!_isCompleteDownload(entity)) continue;
      final RegExpMatch? match = pattern.firstMatch(_basename(entity.path));
      if (match == null) continue;
      final int? surah = int.tryParse(match.group(2)!);
      if (surah == null || surah < 1 || surah > 114) continue;
      entries.add(
        AudioDownloadEntry(
          file: entity,
          type: AudioDownloadType.surah,
          reciterCode: match.group(1)!,
          surah: surah,
          sizeBytes: entity.lengthSync(),
        ),
      );
    }
    return entries;
  }

  Future<List<AudioDownloadEntry>> _scanAyahs() async {
    final Directory dir = await ayahDirectory();
    final RegExp pattern = RegExp(r'^(.+)_(\d{3})_(\d{3})\.mp3$');
    final List<AudioDownloadEntry> entries = <AudioDownloadEntry>[];

    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!_isCompleteDownload(entity)) continue;
      final RegExpMatch? match = pattern.firstMatch(_basename(entity.path));
      if (match == null) continue;
      final int? surah = int.tryParse(match.group(2)!);
      final int? ayah = int.tryParse(match.group(3)!);
      if (surah == null || ayah == null) continue;
      if (surah < 1 || surah > 114 || ayah < 1) continue;
      entries.add(
        AudioDownloadEntry(
          file: entity,
          type: AudioDownloadType.ayah,
          reciterCode: match.group(1)!,
          surah: surah,
          ayah: ayah,
          sizeBytes: entity.lengthSync(),
        ),
      );
    }
    return entries;
  }

  List<AudioDownloadEntry> _bundleCompleteAyahSurahs(
    List<AudioDownloadEntry> entries,
  ) {
    final Map<String, List<AudioDownloadEntry>> grouped =
        <String, List<AudioDownloadEntry>>{};
    for (final AudioDownloadEntry entry in entries) {
      grouped
          .putIfAbsent(
            '${entry.reciterCode}-${entry.surah}',
            () => <AudioDownloadEntry>[],
          )
          .add(entry);
    }

    final List<AudioDownloadEntry> bundled = <AudioDownloadEntry>[];
    for (final List<AudioDownloadEntry> group in grouped.values) {
      group.sort(_compareEntries);
      final int surah = group.first.surah;
      final int totalAyahs = quran.getVerseCount(surah);
      final bool isComplete =
          group.length == totalAyahs &&
          group.every((entry) => entry.ayah != null) &&
          group.map((entry) => entry.ayah).toSet().length == totalAyahs;

      if (!isComplete) {
        bundled.addAll(group);
        continue;
      }

      final AudioDownloadEntry first = group.first;
      bundled.add(
        AudioDownloadEntry(
          file: first.file,
          type: AudioDownloadType.ayahSurah,
          reciterCode: first.reciterCode,
          surah: surah,
          sizeBytes: group.fold<int>(
            0,
            (total, entry) => total + entry.sizeBytes,
          ),
          additionalFiles: group.skip(1).map((entry) => entry.file).toList(),
        ),
      );
    }
    return bundled;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    final int unitIndex = min(
      units.length - 1,
      (log(bytes) / log(1024)).floor(),
    );
    final double value = bytes / pow(1024, unitIndex);
    final String formatted = unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(value >= 10 ? 1 : 2);
    return '$formatted ${units[unitIndex]}';
  }

  String _basename(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  bool _isCompleteDownload(File file) {
    return file.existsSync() && file.lengthSync() > 0;
  }
}
