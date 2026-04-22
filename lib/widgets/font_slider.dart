import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/utils/app_slider_theme.dart';
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
    double fontSize = SettingsDB().get('fontSize', defaultValue: 38.0);
    double fontSizeTranslation = SettingsDB().get(
      'fontSizeTranslation',
      defaultValue: 15.0,
    );

    return Column(
      children: <Widget>[
        _buildSliderRow(
          context: context,
          title: 'Arabic text size',
          subtitle: 'Controls Quran Arabic script size in reading screens.',
          value: fontSize,
          min: 25,
          max: 65,
          onChanged: (value) {
            setState(() {
              fontSize = value;
              SettingsDB().put('fontSize', value);
            });
          },
        ),
        if (widget.showTranslationControls)
          _buildSliderRow(
            context: context,
            title: 'Translation text size',
            subtitle: 'Controls translated verse text size in card view.',
            value: fontSizeTranslation,
            min: 10,
            max: 30,
            onChanged: (value) {
              setState(() {
                fontSizeTranslation = value;
                SettingsDB().put('fontSizeTranslation', value);
              });
            },
          ),
        _FontPreview(
          fontSize: fontSize,
          fontSizeTranslation: fontSizeTranslation,
          showTranslation: widget.showTranslationControls,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Text('A−', style: Theme.of(context).textTheme.labelMedium),
              Expanded(
                child: SliderTheme(
                  data: AppSliderTheme.standard(context),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    label: _formatToThreeSignificantFigures(value),
                    onChanged: onChanged,
                  ),
                ),
              ),
              Text('A+', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  _formatToThreeSignificantFigures(value),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatToThreeSignificantFigures(double value) {
  final String compact = value.toStringAsPrecision(3);
  return compact.contains('.')
      ? compact.replaceFirst(RegExp(r'\.?0+$'), '')
      : compact;
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

    final int translationIndex = SettingsDB().get('translation', defaultValue: 0);
    final quran.Translation selectedTranslation = quran.Translation.values[
        translationIndex.clamp(0, quran.Translation.values.length - 1)];

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
              quran.getVerseTranslation(1, 1, translation: selectedTranslation),
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
