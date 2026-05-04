import 'dart:async';

import 'package:equran/backend/settings_db.dart';
import 'package:equran/prayer/manual_prayer_location_page.dart';
import 'package:equran/prayer/prayer_map_location_page.dart';
import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/prayer/prayer_times_settings_page.dart';
import 'package:equran/prayer/prayer_times_service.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';

class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({
    super.key,
    this.enableLiveCountdown = true,
    this.initialNow,
    this.mapLocationPicker,
  });

  final bool enableLiveCountdown;
  final DateTime? initialNow;
  final PrayerLocationPicker? mapLocationPicker;

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  final PrayerTimesService _service = const PrayerTimesService();
  final PrayerLocationService _locationService = const PrayerLocationService();
  final PrayerSettingsStore _store = PrayerSettingsStore();
  Timer? _timer;
  late DateTime _now;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _now = widget.initialNow ?? DateTime.now();
    if (widget.enableLiveCountdown) {
      _scheduleNextRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ValueListenableBuilder(
        valueListenable: SettingsDB().listener,
        builder: (BuildContext context, Object? value, Widget? child) {
          final PrayerLocation? location = _store.getLocation();
          final PrayerTimeSettings settings = _store.getSettings();
          if (location == null) {
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: <Widget>[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildSetupState(context),
                        const SizedBox(height: 14),
                        _buildDisclaimer(context),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final PrayerDay today = _service.calculateDay(
            date: _now,
            location: location,
            settings: settings,
          );
          final PrayerDay tomorrow = _service.calculateDay(
            date: _now.add(const Duration(days: 1)),
            location: location,
            settings: settings,
          );
          final NextPrayer nextPrayer = _service.nextPrayer(
            day: today,
            tomorrow: tomorrow,
            now: _now,
          );
          final _PrayerHeroTiming heroTiming = _heroTimingFor(nextPrayer);

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildHeroCard(
                        context,
                        today,
                        heroTiming,
                        settings,
                        location,
                      ),
                      const SizedBox(height: 14),
                      _buildPrayerGrid(
                        context,
                        today,
                        heroTiming.entry.kind,
                        settings,
                      ),
                      const SizedBox(height: 14),
                      _buildDisclaimer(context),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    PrayerDay day,
    _PrayerHeroTiming heroTiming,
    PrayerTimeSettings settings,
    PrayerLocation location,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final String methodLabel = prayerMethodDisplayLabel(
      settings: settings,
      effectiveMethod: day.effectiveMethod,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.large),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              colors.primary.withAlpha(isLight ? 34 : 54),
              colors.surfaceContainerLow,
            ),
            Color.alphaBlend(
              colors.tertiary.withAlpha(isLight ? 24 : 42),
              colors.surfaceContainer,
            ),
            colors.surfaceContainerLow,
          ],
        ),
        border: Border.all(
          color: colors.primary.withValues(alpha: isLight ? 0.16 : 0.28),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: isLight ? 0.12 : 0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Next prayer',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Prayer settings',
                  onPressed: _openPrayerSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text.rich(
              key: const Key('next_prayer_title'),
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: heroTiming.entry.kind.label),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: _formatTime(
                      heroTiming.entry.time,
                      settings.use24HourFormat,
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.02,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoPill(
                  icon: Icons.hourglass_bottom_rounded,
                  label: formatPrayerCountdownLabel(
                    heroTiming.countdown,
                    isNow: heroTiming.isNow,
                  ),
                ),
                _InfoPill(
                  icon: Icons.calendar_today_rounded,
                  label: _formatDate(day.date),
                ),
                _InfoPill(icon: Icons.calculate_outlined, label: methodLabel),
              ],
            ),
            const SizedBox(height: 16),
            _LocationSummaryRow(
              location: location,
              onTap: () => _showLocationDetails(location),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.large),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              colors.primary.withAlpha(isLight ? 28 : 48),
              colors.surfaceContainerLow,
            ),
            colors.surfaceContainerLow,
          ],
        ),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: isLight ? 0.1 : 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Icon(
                Icons.add_location_alt_outlined,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Prayer times need a location',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose where to calculate Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.verified_user_outlined,
                  color: colors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your location is used only for local prayer-time calculation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isLocating ? null : _useCurrentLocation,
                  icon: _isLocating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: const Text('Use current location'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _chooseOnMap(null),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Choose on map'),
                ),
                TextButton.icon(
                  onPressed: () => _chooseManually(null),
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Enter coordinates manually'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerGrid(
    BuildContext context,
    PrayerDay day,
    PrayerTimeKind highlightedKind,
    PrayerTimeSettings settings,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= 620;
        return GridView.builder(
          itemCount: day.entries.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: twoColumns ? 2 : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: twoColumns ? 4.25 : 5.3,
          ),
          itemBuilder: (BuildContext context, int index) {
            final PrayerTimeEntry entry = day.entries[index];
            return _PrayerTimeCard(
              entry: entry,
              isNext: entry.kind == highlightedKind,
              use24HourFormat: settings.use24HourFormat,
            );
          },
        );
      },
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Calculated locally. Adjust method in settings. Prayer times are currently experimental and may differ from local mosque or official timetables. Verify with your local mosque.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    if (location != null) {
      await _store.saveLocation(location);
      if (!mounted) return;
      _showMessage('Location saved.');
      return;
    }

    _showLocationError(result);
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
    _showMessage('Location saved.');
  }

  Future<void> _chooseOnMap(PrayerLocation? initialLocation) async {
    final PrayerLocationPicker picker =
        widget.mapLocationPicker ?? showPrayerMapLocationPicker;
    final PrayerLocation? location = await picker(context, initialLocation);
    if (location == null) return;
    await _store.saveLocation(location);
    if (!mounted) return;
    _showMessage('Location saved.');
  }

  Future<void> _showLocationDetails(PrayerLocation location) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return _LocationDetailsSheet(
          location: location,
          isLocating: _isLocating,
          onUpdateCurrentLocation: () {
            Navigator.of(sheetContext).pop();
            _useCurrentLocation();
          },
          onChooseMap: () {
            Navigator.of(sheetContext).pop();
            _chooseOnMap(location);
          },
          onSave: (PrayerLocation updatedLocation) async {
            await _store.saveLocation(updatedLocation);
            if (!mounted) return;
            Navigator.of(sheetContext).pop();
            _showMessage('Location saved.');
          },
        );
      },
    );
  }

  void _openPrayerSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const PrayerTimesSettingsPage(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLocationError(PrayerLocationResult result) {
    final String message = result.message ?? 'Unable to get location.';
    final PrayerLocationFailureReason? reason = result.failureReason;
    final SnackBarAction? action = switch (reason) {
      PrayerLocationFailureReason.servicesDisabled => SnackBarAction(
        label: 'Settings',
        onPressed: () {
          _locationService.openLocationSettings();
        },
      ),
      PrayerLocationFailureReason.permissionDeniedForever => SnackBarAction(
        label: 'App settings',
        onPressed: () {
          _locationService.openAppSettings();
        },
      ),
      _ => null,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _scheduleNextRefresh() {
    _timer?.cancel();
    final DateTime now = DateTime.now();
    final Duration elapsedThisMinute = Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );
    final Duration delay = elapsedThisMinute == Duration.zero
        ? const Duration(minutes: 1)
        : const Duration(minutes: 1) - elapsedThisMinute;

    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
      _scheduleNextRefresh();
    });
  }
}

class _PrayerHeroTiming {
  const _PrayerHeroTiming({
    required this.entry,
    required this.countdown,
    required this.isNow,
  });

  final PrayerTimeEntry entry;
  final Duration countdown;
  final bool isNow;
}

_PrayerHeroTiming _heroTimingFor(NextPrayer nextPrayer) {
  return _PrayerHeroTiming(
    entry: nextPrayer.entry,
    countdown: nextPrayer.countdown,
    isNow: false,
  );
}

class _LocationDetailsSheet extends StatefulWidget {
  const _LocationDetailsSheet({
    required this.location,
    required this.isLocating,
    required this.onUpdateCurrentLocation,
    required this.onChooseMap,
    required this.onSave,
  });

  final PrayerLocation location;
  final bool isLocating;
  final VoidCallback onUpdateCurrentLocation;
  final VoidCallback onChooseMap;
  final Future<void> Function(PrayerLocation location) onSave;

  @override
  State<_LocationDetailsSheet> createState() => _LocationDetailsSheetState();
}

class _LocationDetailsSheetState extends State<_LocationDetailsSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.location.displayLabel,
    );
    _latitudeController = TextEditingController(
      text: widget.location.latitude.toStringAsFixed(6),
    );
    _longitudeController = TextEditingController(
      text: widget.location.longitude.toStringAsFixed(6),
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
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Location details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Location label',
                  hintText: 'Home, work, or city name',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _latitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  helperText: 'Use a value between -90 and 90.',
                  prefixIcon: Icon(Icons.explore_outlined),
                ),
                validator: (String? value) => validatePrayerCoordinate(
                  value,
                  min: -90,
                  max: 90,
                  label: 'Latitude',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _longitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  helperText: 'Use a value between -180 and 180.',
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                validator: (String? value) => validatePrayerCoordinate(
                  value,
                  min: -180,
                  max: 180,
                  label: 'Longitude',
                ),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save changes'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.isLocating || _isSaving
                    ? null
                    : widget.onUpdateCurrentLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Update current location'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isSaving ? null : widget.onChooseMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Choose on map'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _isSaving = true;
    });

    final double latitude = double.parse(_latitudeController.text.trim());
    final double longitude = double.parse(_longitudeController.text.trim());
    final String label = _labelController.text.trim().isEmpty
        ? widget.location.mode.label
        : _labelController.text.trim();
    final bool coordinatesChanged =
        latitude != widget.location.latitude ||
        longitude != widget.location.longitude;

    await widget.onSave(
      PrayerLocation(
        latitude: latitude,
        longitude: longitude,
        label: label,
        mode: coordinatesChanged
            ? PrayerLocationMode.manual
            : widget.location.mode,
        countryCode: coordinatesChanged ? null : widget.location.countryCode,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
  }
}

class _LocationSummaryRow extends StatelessWidget {
  const _LocationSummaryRow({required this.location, required this.onTap});

  final PrayerLocation location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Material(
      color: colors.surface.withValues(alpha: 0.54),
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        key: const Key('prayer_location_summary'),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      location.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calculated locally · Tap for details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.manage_search_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerTimeCard extends StatelessWidget {
  const _PrayerTimeCard({
    required this.entry,
    required this.isNext,
    required this.use24HourFormat,
  });

  final PrayerTimeEntry entry;
  final bool isNext;
  final bool use24HourFormat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isNext ? null : colors.surfaceContainerLow,
        gradient: isNext
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colors.primaryContainer.withValues(
                    alpha: isLight ? 0.9 : 0.7,
                  ),
                  colors.tertiaryContainer.withValues(
                    alpha: isLight ? 0.78 : 0.54,
                  ),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
          color: isNext
              ? colors.primary.withValues(alpha: 0.38)
              : colors.outlineVariant,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: isNext ? 0.14 : 0.06),
            blurRadius: isNext ? 18 : 10,
            offset: Offset(0, isNext ? 8 : 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    (isNext
                            ? colors.surface.withValues(alpha: 0.52)
                            : colors.surfaceContainer)
                        .withValues(alpha: isLight ? 0.88 : 0.74),
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Icon(
                _iconFor(entry.kind),
                color: isNext ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.kind.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isNext ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(entry.time, use24HourFormat),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: isNext ? colors.onPrimaryContainer : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(PrayerTimeKind kind) {
    return switch (kind) {
      PrayerTimeKind.fajr => Icons.nights_stay_rounded,
      PrayerTimeKind.sunrise => Icons.wb_twilight_rounded,
      PrayerTimeKind.dhuhr => Icons.wb_sunny_outlined,
      PrayerTimeKind.asr => Icons.light_mode_outlined,
      PrayerTimeKind.maghrib => Icons.wb_twilight_outlined,
      PrayerTimeKind.isha => Icons.dark_mode_outlined,
    };
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 17, color: colors.primary),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime time, bool use24HourFormat) {
  final int hour = time.hour;
  final int minute = time.minute;
  if (use24HourFormat) {
    return '${_two(hour)}:${_two(minute)}';
  }

  final String period = hour >= 12 ? 'PM' : 'AM';
  final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${_two(minute)} $period';
}

String formatPrayerCountdownLabel(Duration duration, {bool isNow = false}) {
  if (isNow || duration == Duration.zero || duration.isNegative) return 'Now';
  if (duration < const Duration(minutes: 5)) return 'Very soon';

  final int totalMinutes = (duration.inSeconds / 60).ceil();
  final int hours = totalMinutes ~/ 60;
  if (hours > 0) {
    final int minutes = totalMinutes.remainder(60);
    return minutes == 0 ? 'In ${hours}h' : 'In ${hours}h ${minutes}m';
  }
  return 'In ${totalMinutes}m';
}

String _formatDate(DateTime date) {
  const List<String> weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const List<String> months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _two(int value) => value.toString().padLeft(2, '0');
