import 'dart:io';

import 'package:equran/backend/audio_downloads.dart';
import 'package:equran/utils/downloads_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('downloads grouping', () {
    test('groups downloads by reciter and keeps surah/ayah counts', () {
      final File fakeSurahFile = File('surah.mp3');
      final File fakeAyahFile = File('ayah.mp3');
      final AudioDownloadsSummary summary = AudioDownloadsSummary(
        surahDownloads: <AudioDownloadEntry>[
          AudioDownloadEntry(
            file: fakeSurahFile,
            type: AudioDownloadType.surah,
            reciterCode: '1',
            surah: 1,
            sizeBytes: 1024,
          ),
        ],
        ayahDownloads: <AudioDownloadEntry>[
          AudioDownloadEntry(
            file: fakeAyahFile,
            type: AudioDownloadType.ayah,
            reciterCode: '1',
            surah: 2,
            ayah: 255,
            sizeBytes: 2048,
          ),
        ],
      );

      final ReciterDownloadsGroup group = groupDownloadsByReciter(
        summary,
      ).single;

      expect(group.surahs, hasLength(1));
      expect(group.ayahs, hasLength(1));
      expect(group.ayahCount, 1);
      expect(group.sizeBytes, 3072);
      expect(reciterDisplayName('unknown'), 'Reciter unknown');
    });
  });
}
