import 'package:equran/backend/library.dart'
    show AudioDownloadEntry, AudioDownloadService, AudioDownloadsSummary;
import 'package:equran/utils/app_radii.dart';
import 'package:equran/utils/downloads_grouping.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

class _SurahAyahDownloadsGroup {
  const _SurahAyahDownloadsGroup({required this.surah, required this.entries});

  final int surah;
  final List<AudioDownloadEntry> entries;

  int get ayahCount =>
      entries.fold<int>(0, (total, entry) => total + entry.ayahCount);

  int get sizeBytes =>
      entries.fold<int>(0, (total, entry) => total + entry.sizeBytes);
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late Future<AudioDownloadsSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = AudioDownloadService().summary();
  }

  void _refresh() {
    setState(() {
      _summaryFuture = AudioDownloadService().summary();
    });
  }

  Future<void> _deleteEntry(AudioDownloadEntry entry) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Delete Download?'),
        content: Text('Remove ${entry.title} from offline storage?'),
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
      ),
    );

    if (confirm != true) return;
    await AudioDownloadService().deleteEntry(entry);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted ${entry.title}')));
    }
  }

  Future<void> _clearAll(AudioDownloadsSummary summary) async {
    if (summary.allDownloads.isEmpty) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Delete All Downloads?'),
        content: Text(
          'This will remove ${summary.allDownloads.length} downloaded audio files (${AudioDownloadService.formatBytes(summary.totalSizeBytes)}).',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await AudioDownloadService().clearAll();
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted all downloaded audio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return FutureBuilder<AudioDownloadsSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final AudioDownloadsSummary summary = snapshot.data!;
        final List<ReciterDownloadsGroup> reciterGroups =
            groupDownloadsByReciter(summary);
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: <Widget>[
              _buildSummaryCard(theme, summary),
              const SizedBox(height: 16),
              if (reciterGroups.isEmpty)
                _buildEmptyDownloadsCard()
              else
                ...reciterGroups.expand(
                  (group) => <Widget>[
                    _buildReciterSection(group),
                    const SizedBox(height: 16),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(ThemeData theme, AudioDownloadsSummary summary) {
    final ColorScheme colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Offline Audio',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.surahCount} surahs • ${summary.ayahCount} ayahs',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AudioDownloadService.formatBytes(summary.totalSizeBytes),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: summary.allDownloads.isEmpty
                    ? null
                    : () => _clearAll(summary),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Clear All'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDownloadsCard() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Column(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.download_done_outlined),
              title: const Text('No downloaded audio yet.'),
              subtitle: Text(
                'Downloaded surahs and ayahs will appear here grouped by reciter.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReciterSection(ReciterDownloadsGroup group) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<AudioDownloadEntry> surahs = group.surahs;
    final List<_SurahAyahDownloadsGroup> ayahSurahs = _groupAyahsBySurah(
      group.ayahs,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.record_voice_over_rounded),
              title: Text(
                reciterDisplayName(group.reciterCode),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${surahs.length} surahs • ${group.ayahCount} ayahs • ${AudioDownloadService.formatBytes(group.sizeBytes)}',
              ),
            ),
            const Divider(height: 1),
            if (surahs.isNotEmpty) _buildGroupHeader('Surahs', surahs.length),
            ...surahs.map(_buildDownloadTile),
            if (surahs.isNotEmpty && ayahSurahs.isNotEmpty)
              const Divider(height: 1),
            if (ayahSurahs.isNotEmpty)
              _buildGroupHeader('Ayahs', group.ayahCount),
            ...ayahSurahs.map(_buildAyahSurahTile),
          ],
        ),
      ),
    );
  }

  List<_SurahAyahDownloadsGroup> _groupAyahsBySurah(
    List<AudioDownloadEntry> ayahs,
  ) {
    final Map<int, List<AudioDownloadEntry>> grouped =
        <int, List<AudioDownloadEntry>>{};
    for (final AudioDownloadEntry entry in ayahs) {
      grouped.putIfAbsent(entry.surah, () => <AudioDownloadEntry>[]).add(entry);
    }

    final List<_SurahAyahDownloadsGroup> groups = grouped.entries
        .map(
          (entry) =>
              _SurahAyahDownloadsGroup(surah: entry.key, entries: entry.value),
        )
        .toList();
    groups.sort((a, b) => a.surah.compareTo(b.surah));
    return groups;
  }

  Widget _buildAyahSurahTile(_SurahAyahDownloadsGroup group) {
    return ExpansionTile(
      leading: const Icon(Icons.folder_outlined),
      collapsedShape: const Border(),
      shape: const Border(),
      title: Text(quran.getSurahName(group.surah)),
      subtitle: Text(
        '${group.ayahCount} ayahs • ${AudioDownloadService.formatBytes(group.sizeBytes)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(44, 0, 8, 8),
      children: group.entries
          .map((entry) => _buildNestedDownloadTile(entry))
          .toList(growable: false),
    );
  }

  Widget _buildGroupHeader(String title, int count) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadTile(AudioDownloadEntry entry) {
    return ListTile(
      leading: const Icon(Icons.offline_pin_rounded),
      title: Text(entry.title),
      subtitle: Text(
        '${entry.subtitle} • ${AudioDownloadService.formatBytes(entry.sizeBytes)}',
      ),
      trailing: IconButton(
        tooltip: 'Delete download',
        onPressed: () => _deleteEntry(entry),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }

  Widget _buildNestedDownloadTile(AudioDownloadEntry entry) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(left: 12, right: 0),
      title: Text(entry.title),
      subtitle: Text(
        '${entry.subtitle} • ${AudioDownloadService.formatBytes(entry.sizeBytes)}',
      ),
      trailing: IconButton(
        tooltip: 'Delete download',
        onPressed: () => _deleteEntry(entry),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }
}
