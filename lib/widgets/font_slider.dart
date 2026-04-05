import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/widgets/library.dart' show ReadQuranCard;
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

class FontSlider extends StatefulWidget {
  const FontSlider({super.key});

  @override
  State<FontSlider> createState() => _FontSliderState();
}

class _FontSliderState extends State<FontSlider> {
  @override
  Widget build(BuildContext context) {
    double fontSize = SettingsDB().get("fontSize", defaultValue: 38.0);
    double fontSizeTranslation = SettingsDB().get("fontSizeTranslation", defaultValue: 20.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        child: Column(
          children: [
            ListTile(
              title: const Center(child: Text("Font Size")),
              subtitle: Slider(
                  value: fontSize,
                  min: 30.0,
                  max: 65.0,
                  label: (fontSize / 2).round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      fontSize = value;
                      SettingsDB().put("fontSize", value);
                    });
                  }),
                  
            ),
              ListTile(
              title: const Center(child: Text("Translation Font Size")),
              subtitle: Slider(
                  value: fontSizeTranslation,
                  min: 15.0,
                  max: 30.0,
                  label: (fontSizeTranslation / 2).round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      fontSizeTranslation = value;
                      SettingsDB().put("fontSizeTranslation", value);
                    });
                  }),
                  
            ),
            ReadQuranCard(
                currentChapter: 1,
                currentVerse: 1,
                totalVerses: 7,
                fontSize: fontSize,
                fontSizeTranslation: fontSizeTranslation,
                juzNumber: 1,
                url: "",
                translation: quran.getVerseTranslation(1, 1),
                verse: quran.getVerse(1, 1))
          ],
        ),
      ),
    );
  }
}
