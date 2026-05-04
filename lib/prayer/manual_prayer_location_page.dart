import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';

String? validatePrayerCoordinate(
  String? value, {
  required double min,
  required double max,
  required String label,
}) {
  final double? parsed = double.tryParse(value?.trim() ?? '');
  final String fieldName = label.toLowerCase();
  if ((value ?? '').trim().isEmpty) return 'Enter $fieldName.';
  if (parsed == null) return '$label should be a number.';
  if (parsed < min || parsed > max) {
    return '$label must be between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)}.';
  }
  return null;
}

class ManualPrayerLocationPage extends StatefulWidget {
  const ManualPrayerLocationPage({super.key, this.initialLocation});

  final PrayerLocation? initialLocation;

  @override
  State<ManualPrayerLocationPage> createState() =>
      _ManualPrayerLocationPageState();
}

class _ManualPrayerLocationPageState extends State<ManualPrayerLocationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  @override
  void initState() {
    super.initState();
    final PrayerLocation? initialLocation = widget.initialLocation;
    _labelController = TextEditingController(
      text: initialLocation?.mode == PrayerLocationMode.manual
          ? initialLocation?.label
          : null,
    );
    _latitudeController = TextEditingController(
      text: initialLocation == null
          ? ''
          : initialLocation.latitude.toStringAsFixed(6),
    );
    _longitudeController = TextEditingController(
      text: initialLocation == null
          ? ''
          : initialLocation.longitude.toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose location manually')),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.add_location_alt_outlined,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Coordinates for prayer times',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter the latitude and longitude for the city, area, or address you want to use.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _labelController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Location label',
                                hintText: 'Home, work, or city name',
                                helperText:
                                    'Optional. This is shown instead of coordinates.',
                                prefixIcon: Icon(Icons.label_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _latitudeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                hintText: 'Example: 25.2048',
                                helperText: 'Use a value between -90 and 90.',
                                prefixIcon: Icon(Icons.explore_outlined),
                              ),
                              validator: (String? value) =>
                                  validatePrayerCoordinate(
                                    value,
                                    min: -90,
                                    max: 90,
                                    label: 'Latitude',
                                  ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _longitudeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                hintText: 'Example: 55.2708',
                                helperText: 'Use a value between -180 and 180.',
                                prefixIcon: Icon(Icons.public_rounded),
                              ),
                              validator: (String? value) =>
                                  validatePrayerCoordinate(
                                    value,
                                    min: -180,
                                    max: 180,
                                    label: 'Longitude',
                                  ),
                              onFieldSubmitted: (_) => _save(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.map_outlined,
                              color: colors.onSecondaryContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Saved on this device and used only for local prayer-time calculation.',
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
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save location'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    final double latitude = double.parse(_latitudeController.text.trim());
    final double longitude = double.parse(_longitudeController.text.trim());
    final String label = _labelController.text.trim().isEmpty
        ? 'Manual location'
        : _labelController.text.trim();

    Navigator.of(context).pop(
      PrayerLocation(
        latitude: latitude,
        longitude: longitude,
        label: label,
        mode: PrayerLocationMode.manual,
      ),
    );
  }
}
