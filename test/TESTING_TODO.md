# Testing TODO

This pass adds focused unit/widget coverage around extracted logic and stable UI
surfaces. The remaining high-value coverage should be added after the large
runtime services are made injectable:

- End-to-end `ReadPage` flows for jump-to-verse, long-press ayah actions,
  tafsir sheets, and share-image capture with fake platform services.
- Full audio state-machine tests with fake `AudioPlayer`, fake downloads, and
  fake `QuranAudioService`.
- Downloads page delete/clear interactions against an injectable fake
  `AudioDownloadService`.
- Backup/restore and URL/share settings flows with platform fakes.
