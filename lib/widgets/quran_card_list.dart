import 'package:dynamic_height_grid_view/dynamic_height_grid_view.dart';
import 'package:equran/backend/surah_db.dart';
import 'package:equran/backend/surah_model.dart';
import 'package:equran/widgets/quran_card.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

class QuranCardList extends StatefulWidget {
  final String searchQuery;

  const QuranCardList({super.key, required this.searchQuery});

  @override
  State<QuranCardList> createState() => _QuranCardListState();
}

class _QuranCardListState extends State<QuranCardList>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder<List<Surah>>(
      future: _fetchSurahs(),
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
              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: data.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  return QuranCard(surah: data[index], compact: false);
                },
              );
            }

            return DynamicHeightGridView(
              physics: const BouncingScrollPhysics(),
              shrinkWrap: true,
              itemCount: data.length,
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              builder: (BuildContext context, int index) {
                return QuranCard(surah: data[index], compact: true);
              },
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
              surah.name.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
              surah.transliteration
                  .toLowerCase()
                  .contains(widget.searchQuery.toLowerCase()) ||
              surah.id.toString() == widget.searchQuery,
        )
        .toList();
  }

  @override
  bool get wantKeepAlive => true;
}
