import 'package:dynamic_height_grid_view/dynamic_height_grid_view.dart';
import 'package:equran/backend/surah_db.dart';
import 'package:equran/backend/surah_model.dart';
import 'package:equran/widgets/quran_card.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

class QuranCardList extends StatefulWidget {
  final String searchQuery;
  final Widget? header;

  const QuranCardList({super.key, required this.searchQuery, this.header});

  @override
  State<QuranCardList> createState() => _QuranCardListState();
}

class _QuranCardListState extends State<QuranCardList>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _fallbackScrollController = ScrollController();
  late Future<List<Surah>> _surahsFuture;

  @override
  void initState() {
    super.initState();
    _surahsFuture = _fetchSurahs();
  }

  @override
  void didUpdateWidget(covariant QuranCardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _surahsFuture = _fetchSurahs();
    }
  }

  @override
  void dispose() {
    _fallbackScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ScrollController scrollController =
        PrimaryScrollController.maybeOf(context) ?? _fallbackScrollController;

    return FutureBuilder<List<Surah>>(
      future: _surahsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Surah>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Surah> data = snapshot.data ?? <Surah>[];
        if (data.isEmpty) {
          return const Center(child: Text('No surahs found.'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final bool isWebLike = width >= 1200;
            final int columns = isWebLike ? 3 : (width >= 700 ? 2 : 1);

            if (columns == 1) {
              return Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                interactive: true,
                child: ListView.builder(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 30),
                  itemCount: data.length + (widget.header == null ? 0 : 1),
                  itemBuilder: (BuildContext context, int index) {
                    if (widget.header != null && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: widget.header!,
                      );
                    }

                    final int dataIndex =
                        index - (widget.header == null ? 0 : 1);
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: dataIndex == data.length - 1 ? 0 : 6,
                      ),
                      child: QuranCard(surah: data[dataIndex], compact: false),
                    );
                  },
                ),
              );
            }

            return Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              interactive: true,
              child: CustomScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  if (widget.header != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: widget.header!,
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 16),
                    sliver: SliverDynamicHeightGridView(
                      itemCount: data.length,
                      crossAxisCount: columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      builder: (BuildContext context, int index) {
                        return QuranCard(
                          surah: data[index],
                          compact: true,
                          reduceTitleSize: columns == 2,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Surah>> _fetchSurahs() async {
    List<Surah> surahs = <Surah>[];

    if (SurahDB().contains("surahsList")) {
      final cachedData = SurahDB().get("surahsList");
      if (cachedData is List) {
        surahs = cachedData.cast<Surah>();
      } else {
        throw Exception("Cached data is not valid");
      }
    } else {
      for (int i = 1; i <= 114; i++) {
        surahs.add(
          Surah(
            id: i,
            transliteration: quran.getSurahName(i),
            verses: quran.getVerseCount(i),
            name: quran.getSurahNameArabic(i),
            englishName: quran.getSurahNameEnglish(i),
          ),
        );
      }
      await SurahDB().put("surahsList", surahs);
    }

    if (widget.searchQuery.isEmpty) {
      return surahs;
    }

    return surahs
        .where(
          (surah) =>
              surah.name.toLowerCase().contains(
                widget.searchQuery.toLowerCase(),
              ) ||
              surah.transliteration.toLowerCase().contains(
                widget.searchQuery.toLowerCase(),
              ) ||
              surah.id.toString() == widget.searchQuery,
        )
        .toList();
  }

  @override
  bool get wantKeepAlive => true;
}
