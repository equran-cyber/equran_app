import 'package:equran/duas/hisn_al_muslim_models.dart';
import 'package:equran/duas/hisn_al_muslim_repository.dart';
import 'package:equran/duas/widgets/dua_card.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';

class DuasCategoryPage extends StatefulWidget {
  const DuasCategoryPage({
    super.key,
    required this.categoryIndex,
    required this.repository,
    this.focusDuaId,
  });

  final DuaCategoryIndex categoryIndex;
  final HisnAlMuslimRepository repository;
  final String? focusDuaId;

  @override
  State<DuasCategoryPage> createState() => _DuasCategoryPageState();
}

class _DuasCategoryPageState extends State<DuasCategoryPage> {
  late final Future<DuaCategory> _categoryFuture;

  @override
  void initState() {
    super.initState();
    _categoryFuture = widget.repository.loadCategoryByAsset(
      widget.categoryIndex.asset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryIndex.title,
          textDirection: TextDirection.rtl,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<DuaCategory>(
        future: _categoryFuture,
        builder: (BuildContext context, AsyncSnapshot<DuaCategory> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          }

          if (snapshot.hasError) {
            return const _CategoryMessage(
              icon: Icons.error_outline_rounded,
              title: 'Category unavailable',
              message: 'This Hisn al Muslim category could not be loaded.',
            );
          }

          final DuaCategory? category = snapshot.data;
          if (category == null || category.duas.isEmpty) {
            return const _CategoryMessage(
              icon: Icons.menu_book_outlined,
              title: 'No duas found',
              message: 'This category does not contain any duas.',
            );
          }

          return _CategoryContent(
            category: category,
            focusDuaId: widget.focusDuaId,
          );
        },
      ),
    );
  }
}

class _CategoryContent extends StatelessWidget {
  const _CategoryContent({required this.category, this.focusDuaId});

  final DuaCategory category;
  final String? focusDuaId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          category.title,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.45,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${category.duas.length} ${category.duas.length == 1 ? 'dua' : 'duas'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (int index = 0; index < category.duas.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        border:
                            category.duas[index].id == focusDuaId ||
                                category.duas[index].legacyFavouriteId ==
                                    focusDuaId
                            ? Border.all(color: colors.primary, width: 2)
                            : null,
                      ),
                      child: DuaCard(
                        dua: category.duas[index],
                        number: index + 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryMessage extends StatelessWidget {
  const _CategoryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: colors.primary, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
