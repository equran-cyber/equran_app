import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

class FontSlider extends StatefulWidget {
  const FontSlider({super.key, required this.showTranslationControls});

  final bool showTranslationControls;

  @override
  State<FontSlider> createState() => _FontSliderState();
}

class _FontSliderState extends State<FontSlider> {
  @override
  Widget build(BuildContext context) {
    double fontSize = SettingsDB().get("fontSize", defaultValue: 38.0);
    double fontSizeTranslation = SettingsDB().get(
      "fontSizeTranslation",
      defaultValue: 15.0,
    );
    return Column(
      children: [
        ListTile(
          title: const Center(child: Text("Font Size")),
          subtitle: Slider(
            value: fontSize,
            min: 25.0,
            max: 65.0,
            label: (fontSize / 2).round().toString(),
            onChanged: (double value) {
              setState(() {
                fontSize = value;
                SettingsDB().put("fontSize", value);
              });
            },
          ),
        ),
        if (widget.showTranslationControls)
          ListTile(
            title: const Center(child: Text("Translation Font Size")),
            subtitle: Slider(
              value: fontSizeTranslation,
              min: 10.0,
              max: 30.0,
              label: (fontSizeTranslation / 2).round().toString(),
              onChanged: (double value) {
                setState(() {
                  fontSizeTranslation = value;
                  SettingsDB().put("fontSizeTranslation", value);
                });
              },
            ),
          ),
        _FontPreview(
          fontSize: fontSize,
          fontSizeTranslation: fontSizeTranslation,
          showTranslation: widget.showTranslationControls,
        ),
      ],
    );
  }
}

class _FontPreview extends StatelessWidget {
  const _FontPreview({
    required this.fontSize,
    required this.fontSizeTranslation,
    required this.showTranslation,
  });

  final double fontSize;
  final double fontSizeTranslation;
  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            quran.getVerse(1, 1),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Hafs',
              height: 1.65,
              fontSize: fontSize,
            ),
          ),
          if (showTranslation) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              quran.getVerseTranslation(1, 1),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: fontSizeTranslation,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
