import 'package:equran/backend/daily_guidance_service.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';

class DailyGuidancePage extends StatefulWidget {
  const DailyGuidancePage({super.key});

  @override
  State<DailyGuidancePage> createState() => _DailyGuidancePageState();
}

class _DailyGuidancePageState extends State<DailyGuidancePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      child: FutureBuilder<List<DailyGuidanceCategory>>(
        future: DailyGuidanceService.instance.loadCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load daily guidance.'));
          }

          final List<DailyGuidanceCategory> categories =
              snapshot.data ?? const <DailyGuidanceCategory>[];
          final List<DailyGuidanceCategory> filtered = categories
              .map((category) => DailyGuidanceCategory(
                    id: category.id,
                    title: category.title,
                    items: category.items
                        .where((entry) => entry.matchesQuery(_query))
                        .toList(),
                  ))
              .where((category) => category.items.isNotEmpty)
              .toList();

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: <Widget>[
              SearchBar(
                controller: _searchController,
                leading: const Icon(Icons.search_rounded),
                hintText: 'Search duas and hadiths',
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    'No results found.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ...filtered.map(_buildCategoryTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryTile(DailyGuidanceCategory category) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(category.title),
          subtitle: Text('${category.items.length} items'),
          children: category.items
              .map((entry) => _GuidanceCard(entry: entry))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.entry});

  final DailyGuidanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: colors.outlineVariant.withAlpha(170)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Hafs', fontSize: 28, height: 1.5),
          ),
          if (entry.transliteration.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              entry.transliteration,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(entry.translation, style: theme.textTheme.bodyMedium),
          if (entry.reference.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              entry.reference,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
