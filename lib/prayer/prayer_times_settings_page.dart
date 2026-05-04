import 'package:equran/prayer/manual_prayer_location_page.dart';
import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/widgets/app_selection_dialog.dart';
import 'package:flutter/material.dart';

class PrayerTimesSettingsPage extends StatefulWidget {
  const PrayerTimesSettingsPage({super.key});

  @override
  State<PrayerTimesSettingsPage> createState() =>
      _PrayerTimesSettingsPageState();
}

class _PrayerTimesSettingsPageState extends State<PrayerTimesSettingsPage> {
  final PrayerSettingsStore _store = PrayerSettingsStore();
  final PrayerLocationService _locationService = const PrayerLocationService();
  late PrayerTimeSettings _settings;
  PrayerLocation? _location;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _settings = _store.getSettings();
    _location = _store.getLocation();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times Settings')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: <Widget>[
          _buildSettingsGroup(
            context: context,
            title: 'Location',
            subtitle: _locationSubtitle,
            icon: Icons.location_on_outlined,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.my_location_rounded),
                title: const Text('Use current location'),
                subtitle: const Text(
                  'Request permission and save GPS coordinates.',
                ),
                trailing: _isLocating
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _isLocating ? null : _useCurrentLocation,
              ),
              ListTile(
                leading: const Icon(Icons.edit_location_alt_outlined),
                title: const Text('Choose manually'),
                subtitle: const Text('Enter latitude and longitude.'),
                onTap: () => _chooseManually(_location),
              ),
              if (_location != null)
                ListTile(
                  leading: const Icon(Icons.location_disabled_outlined),
                  title: const Text('Clear saved location'),
                  subtitle: const Text(
                    'Prayer times will pause until you choose again.',
                  ),
                  onTap: _clearLocation,
                ),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: 'Calculation',
            subtitle: 'Method, Asr, and time format',
            icon: Icons.calculate_outlined,
            children: <Widget>[
              ListTile(
                title: const Text('Calculation method'),
                subtitle: Text(_settings.method.label),
                onTap: _selectCalculationMethod,
              ),
              ListTile(
                title: const Text('Asr method'),
                subtitle: Text(_settings.asrMethod.label),
                onTap: _selectAsrMethod,
              ),
              ListTile(
                title: const Text('Time format'),
                subtitle: Text(
                  _settings.use24HourFormat ? '24-hour' : '12-hour',
                ),
                onTap: _selectTimeFormat,
              ),
              if (_settings.method == PrayerCalculationMethod.custom)
                _buildCustomMethodCard(theme),
            ],
          ),
          _buildSettingsGroup(
            context: context,
            title: 'Manual Offsets',
            subtitle: 'Fine tune calculated times',
            icon: Icons.tune_rounded,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Text(
                  'Offsets are applied after the base calculation. Use positive or negative minutes only when you need to match a trusted local timetable.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
              for (final PrayerTimeKind prayer in PrayerTimeKind.displayOrder)
                ListTile(
                  title: Text(prayer.label),
                  subtitle: Text(
                    _offsetLabel(_settings.offsets.forPrayer(prayer)),
                  ),
                  onTap: () => _editOffset(prayer),
                ),
            ],
          ),
          _buildDisclaimer(context),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          child: ExpansionTile(
            initiallyExpanded: true,
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomMethodCard(ThemeData theme) {
    final ColorScheme colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: <Widget>[
                  Icon(Icons.construction_rounded, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Custom Method',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Fajr angle'),
              subtitle: Text(
                '${_settings.customFajrAngle.toStringAsFixed(1)}°',
              ),
              onTap: () => _editDoubleSetting(
                title: 'Fajr angle',
                currentValue: _settings.customFajrAngle,
                min: 0,
                max: 30,
                suffix: 'degrees',
                onChanged: (double value) =>
                    _saveSettings(_settings.copyWith(customFajrAngle: value)),
              ),
            ),
            ListTile(
              title: const Text('Isha angle'),
              subtitle: Text(
                '${_settings.customIshaAngle.toStringAsFixed(1)}°',
              ),
              onTap: () => _editDoubleSetting(
                title: 'Isha angle',
                currentValue: _settings.customIshaAngle,
                min: 0,
                max: 30,
                suffix: 'degrees',
                onChanged: (double value) =>
                    _saveSettings(_settings.copyWith(customIshaAngle: value)),
              ),
            ),
            ListTile(
              title: const Text('Isha interval'),
              subtitle: Text(
                _settings.customIshaInterval == null
                    ? 'Use Isha angle'
                    : '${_settings.customIshaInterval} minutes after Maghrib',
              ),
              onTap: () => _editOptionalIntSetting(
                title: 'Isha interval',
                currentValue: _settings.customIshaInterval,
                min: 0,
                max: 240,
                emptyLabel: 'Leave blank to use Isha angle.',
                onChanged: (int? value) =>
                    _saveSettings(_settings.withCustomIshaInterval(value)),
              ),
            ),
            ListTile(
              title: const Text('Maghrib angle'),
              subtitle: Text(
                _settings.customMaghribAngle == null
                    ? 'Use sunset'
                    : '${_settings.customMaghribAngle!.toStringAsFixed(1)}°',
              ),
              onTap: () => _editOptionalDoubleSetting(
                title: 'Maghrib angle',
                currentValue: _settings.customMaghribAngle,
                min: 0,
                max: 10,
                emptyLabel: 'Leave blank to use sunset.',
                onChanged: (double? value) =>
                    _saveSettings(_settings.withCustomMaghribAngle(value)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Prayer times are currently experimental and may differ from local mosque or official timetables. Please verify before relying on them.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectCalculationMethod() async {
    final PrayerCalculationMethod? selected =
        await _showSelectionDialog<PrayerCalculationMethod>(
          title: 'Calculation Method',
          icon: Icons.calculate_outlined,
          selectedValue: _settings.method,
          options: PrayerCalculationMethod.values
              .map(
                (
                  PrayerCalculationMethod method,
                ) => AppSelectionOption<PrayerCalculationMethod>(
                  value: method,
                  title: method.label,
                  subtitle: method == PrayerCalculationMethod.auto
                      ? 'Choose a method from the saved country when available.'
                      : null,
                ),
              )
              .toList(),
        );
    if (selected == null) return;
    await _saveSettings(_settings.copyWith(method: selected));
  }

  Future<void> _selectAsrMethod() async {
    final PrayerAsrMethod? selected =
        await _showSelectionDialog<PrayerAsrMethod>(
          title: 'Asr Method',
          icon: Icons.wb_sunny_outlined,
          selectedValue: _settings.asrMethod,
          options: PrayerAsrMethod.values
              .map(
                (PrayerAsrMethod method) => AppSelectionOption<PrayerAsrMethod>(
                  value: method,
                  title: method.label,
                ),
              )
              .toList(),
        );
    if (selected == null) return;
    await _saveSettings(_settings.copyWith(asrMethod: selected));
  }

  Future<void> _selectTimeFormat() async {
    final bool? use24HourFormat = await _showSelectionDialog<bool>(
      title: 'Time Format',
      icon: Icons.schedule_rounded,
      selectedValue: _settings.use24HourFormat,
      options: const <AppSelectionOption<bool>>[
        AppSelectionOption<bool>(value: false, title: '12-hour'),
        AppSelectionOption<bool>(value: true, title: '24-hour'),
      ],
    );
    if (use24HourFormat == null) return;
    await _saveSettings(_settings.copyWith(use24HourFormat: use24HourFormat));
  }

  Future<T?> _showSelectionDialog<T>({
    required String title,
    required IconData icon,
    required T selectedValue,
    required List<AppSelectionOption<T>> options,
  }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) => AppSelectionDialog<T>(
        title: title,
        icon: icon,
        selectedValue: selectedValue,
        options: options,
      ),
    );
  }

  Future<void> _editOffset(PrayerTimeKind prayer) async {
    final int? value = await _showNumberDialog<int>(
      title: '${prayer.label} offset',
      currentValue: _settings.offsets.forPrayer(prayer),
      helperText: 'Positive or negative minutes applied after calculation.',
      parser: int.tryParse,
      validator: (int value) => value >= -120 && value <= 120,
      formatter: (int value) => value.toString(),
    );
    if (value == null) return;
    await _saveSettings(
      _settings.copyWith(
        offsets: _settings.offsets.copyWithPrayer(prayer, value),
      ),
    );
  }

  Future<void> _editDoubleSetting({
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) async {
    final double? value = await _showNumberDialog<double>(
      title: title,
      currentValue: currentValue,
      helperText:
          'Enter a value between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)} $suffix.',
      parser: double.tryParse,
      validator: (double value) => value >= min && value <= max,
      formatter: (double value) => value.toStringAsFixed(1),
    );
    if (value == null) return;
    onChanged(value);
  }

  Future<void> _editOptionalIntSetting({
    required String title,
    required int? currentValue,
    required int min,
    required int max,
    required String emptyLabel,
    required ValueChanged<int?> onChanged,
  }) async {
    final _OptionalNumberResult<int>? result =
        await _showOptionalNumberDialog<int>(
          title: title,
          currentValue: currentValue,
          helperText: emptyLabel,
          parser: int.tryParse,
          validator: (int value) => value >= min && value <= max,
          formatter: (int value) => value.toString(),
        );
    if (result == null) return;
    onChanged(result.value);
  }

  Future<void> _editOptionalDoubleSetting({
    required String title,
    required double? currentValue,
    required double min,
    required double max,
    required String emptyLabel,
    required ValueChanged<double?> onChanged,
  }) async {
    final _OptionalNumberResult<double>? result =
        await _showOptionalNumberDialog<double>(
          title: title,
          currentValue: currentValue,
          helperText: emptyLabel,
          parser: double.tryParse,
          validator: (double value) => value >= min && value <= max,
          formatter: (double value) => value.toStringAsFixed(1),
        );
    if (result == null) return;
    onChanged(result.value);
  }

  Future<T?> _showNumberDialog<T extends num>({
    required String title,
    required T currentValue,
    required String helperText,
    required T? Function(String value) parser,
    required bool Function(T value) validator,
    required String Function(T value) formatter,
  }) {
    return _showNumberDialogInternal<T>(
      title: title,
      currentValue: currentValue,
      helperText: helperText,
      parser: parser,
      validator: validator,
      formatter: formatter,
      allowEmpty: false,
    );
  }

  Future<_OptionalNumberResult<T>?> _showOptionalNumberDialog<T extends num>({
    required String title,
    required T? currentValue,
    required String helperText,
    required T? Function(String value) parser,
    required bool Function(T value) validator,
    required String Function(T value) formatter,
  }) {
    return _showOptionalNumberDialogInternal<T>(
      title: title,
      currentValue: currentValue,
      helperText: helperText,
      parser: parser,
      validator: validator,
      formatter: formatter,
      allowEmpty: true,
    );
  }

  Future<T?> _showNumberDialogInternal<T extends num>({
    required String title,
    required T? currentValue,
    required String helperText,
    required T? Function(String value) parser,
    required bool Function(T value) validator,
    required String Function(T value) formatter,
    required bool allowEmpty,
  }) {
    final TextEditingController controller = TextEditingController(
      text: currentValue == null ? '' : formatter(currentValue),
    );
    return showDialog<T?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: InputDecoration(helperText: helperText),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String raw = controller.text.trim();
                if (allowEmpty && raw.isEmpty) {
                  Navigator.of(context).pop(null);
                  return;
                }
                final T? value = parser(raw);
                if (value == null || !validator(value)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid value.')),
                  );
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<_OptionalNumberResult<T>?>
  _showOptionalNumberDialogInternal<T extends num>({
    required String title,
    required T? currentValue,
    required String helperText,
    required T? Function(String value) parser,
    required bool Function(T value) validator,
    required String Function(T value) formatter,
    required bool allowEmpty,
  }) {
    final TextEditingController controller = TextEditingController(
      text: currentValue == null ? '' : formatter(currentValue),
    );
    return showDialog<_OptionalNumberResult<T>?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: InputDecoration(helperText: helperText),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String raw = controller.text.trim();
                if (allowEmpty && raw.isEmpty) {
                  Navigator.of(
                    context,
                  ).pop(const _OptionalNumberResult<Never>(null));
                  return;
                }
                final T? value = parser(raw);
                if (value == null || !validator(value)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid value.')),
                  );
                  return;
                }
                Navigator.of(context).pop(_OptionalNumberResult<T>(value));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });
    final PrayerLocationResult result = await _locationService
        .currentDeviceLocation();
    if (!mounted) return;
    setState(() {
      _isLocating = false;
    });

    final PrayerLocation? location = result.location;
    if (location == null) {
      _showMessage(result.message ?? 'Unable to get location.');
      return;
    }
    await _store.saveLocation(location);
    if (!mounted) return;
    setState(() {
      _location = location;
    });
    _showMessage('Location saved.');
  }

  Future<void> _chooseManually(PrayerLocation? initialLocation) async {
    final PrayerLocation? location = await Navigator.of(context).push(
      MaterialPageRoute<PrayerLocation>(
        builder: (BuildContext context) =>
            ManualPrayerLocationPage(initialLocation: initialLocation),
      ),
    );
    if (location == null) return;
    await _store.saveLocation(location);
    if (!mounted) return;
    setState(() {
      _location = location;
    });
    _showMessage('Location saved.');
  }

  Future<void> _clearLocation() async {
    await _store.clearLocation();
    if (!mounted) return;
    setState(() {
      _location = null;
    });
    _showMessage('Location cleared.');
  }

  Future<void> _saveSettings(PrayerTimeSettings settings) async {
    await _store.saveSettings(settings);
    if (!mounted) return;
    setState(() {
      _settings = settings;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _locationSubtitle {
    final PrayerLocation? location = _location;
    if (location == null) return 'Choose a location before calculating';
    return '${location.label} • ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
  }

  String _offsetLabel(int offset) {
    if (offset == 0) return 'No manual adjustment';
    return '${offset > 0 ? '+' : ''}$offset minutes';
  }
}

class _OptionalNumberResult<T extends num> {
  const _OptionalNumberResult(this.value);

  final T? value;
}

extension PrayerOffsetsUpdate on PrayerOffsets {
  PrayerOffsets copyWithPrayer(PrayerTimeKind prayer, int value) {
    return PrayerOffsets(
      fajr: prayer == PrayerTimeKind.fajr ? value : fajr,
      sunrise: prayer == PrayerTimeKind.sunrise ? value : sunrise,
      dhuhr: prayer == PrayerTimeKind.dhuhr ? value : dhuhr,
      asr: prayer == PrayerTimeKind.asr ? value : asr,
      maghrib: prayer == PrayerTimeKind.maghrib ? value : maghrib,
      isha: prayer == PrayerTimeKind.isha ? value : isha,
    );
  }
}

extension PrayerCustomSettingsUpdate on PrayerTimeSettings {
  PrayerTimeSettings withCustomIshaInterval(int? value) {
    return PrayerTimeSettings(
      method: method,
      customFajrAngle: customFajrAngle,
      customIshaAngle: customIshaAngle,
      customIshaInterval: value,
      customMaghribAngle: customMaghribAngle,
      asrMethod: asrMethod,
      offsets: offsets,
      use24HourFormat: use24HourFormat,
    );
  }

  PrayerTimeSettings withCustomMaghribAngle(double? value) {
    return PrayerTimeSettings(
      method: method,
      customFajrAngle: customFajrAngle,
      customIshaAngle: customIshaAngle,
      customIshaInterval: customIshaInterval,
      customMaghribAngle: value,
      asrMethod: asrMethod,
      offsets: offsets,
      use24HourFormat: use24HourFormat,
    );
  }
}
