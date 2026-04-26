import 'package:equran/backend/audio_downloads.dart';
import 'package:equran/utils/reciter.dart';

class ReciterDownloadsGroup {
  const ReciterDownloadsGroup({
    required this.reciterCode,
    required this.entries,
  });

  final String reciterCode;
  final List<AudioDownloadEntry> entries;

  List<AudioDownloadEntry> get surahs => entries
      .where((entry) => entry.type == AudioDownloadType.surah)
      .toList(growable: false);

  List<AudioDownloadEntry> get ayahs => entries
      .where((entry) => entry.type != AudioDownloadType.surah)
      .toList(growable: false);

  int get ayahCount =>
      ayahs.fold<int>(0, (total, entry) => total + entry.ayahCount);

  int get sizeBytes =>
      entries.fold<int>(0, (total, entry) => total + entry.sizeBytes);
}

List<ReciterDownloadsGroup> groupDownloadsByReciter(
  AudioDownloadsSummary summary,
) {
  final Map<String, List<AudioDownloadEntry>> grouped =
      <String, List<AudioDownloadEntry>>{};
  for (final AudioDownloadEntry entry in summary.allDownloads) {
    grouped
        .putIfAbsent(entry.reciterCode, () => <AudioDownloadEntry>[])
        .add(entry);
  }

  final List<ReciterDownloadsGroup> groups = grouped.entries
      .map(
        (entry) =>
            ReciterDownloadsGroup(reciterCode: entry.key, entries: entry.value),
      )
      .toList();
  groups.sort(
    (a, b) => reciterDisplayName(
      a.reciterCode,
    ).compareTo(reciterDisplayName(b.reciterCode)),
  );
  return groups;
}

String reciterDisplayName(String reciterCode) {
  final String normalizedCode = AppReciter.normalizeCode(reciterCode);
  final bool isKnownReciter = AppReciter.values.any(
    (reciter) => reciter.code == normalizedCode,
  );
  if (!isKnownReciter) return 'Reciter $reciterCode';
  return AppReciter.fromCode(normalizedCode).englishName;
}
