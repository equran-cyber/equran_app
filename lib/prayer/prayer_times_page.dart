import 'dart:async';

import 'package:equran/backend/settings_db.dart';
import 'package:equran/prayer/manual_prayer_location_page.dart';
import 'package:equran/prayer/prayer_map_location_page.dart';
import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_notification_service.dart';
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
    this.locationService,
    this.notificationService,
  });

  final bool enableLiveCountdown;
  final DateTime? initialNow;
  final PrayerLocationPicker? mapLocationPicker;
  final PrayerLocationService? locationService;
  final PrayerNotificationService? notificationService;

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  final PrayerTimesService _service = const PrayerTimesService();
  final PrayerSettingsStore _store = PrayerSettingsStore();
  late final PrayerLocationService _locationService;
  late final PrayerNotificationService _notificationService;
  Timer? _timer;
  late DateTime _now;
  DateTime? _selectedDate;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? const PrayerLocationService();
    _notificationService =
        widget.notificationService ?? PrayerNotificationService();
    _now = widget.initialNow ?? DateTime.now();
    unawaited(_refreshCurrentDeviceLocationOnEntry());
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

          final DateTime todayDate = _service.calendarDateForInstant(
            instant: _now,
            location: location,
            settings: settings,
          );
          final PrayerDay today = _service.calculateDay(
            date: todayDate,
            location: location,
            settings: settings,
          );
          final DateTime selectedDate = _selectedDate ?? todayDate;
          final bool isViewingToday = _isSameCalendarDate(
            selectedDate,
            todayDate,
          );
          final PrayerDay selectedDay = isViewingToday
              ? today
              : _service.calculateDay(
                  date: selectedDate,
                  location: location,
                  settings: settings,
                );
          final _PrayerHeroTiming heroTiming;
          final PrayerTimeKind? highlightedPrayer;
          if (isViewingToday) {
            final PrayerDay tomorrow = _service.calculateDay(
              date: DateTime(
                todayDate.year,
                todayDate.month,
                todayDate.day + 1,
              ),
              location: location,
              settings: settings,
            );
            final NextPrayer nextPrayer = _service.nextPrayer(
              day: today,
              tomorrow: tomorrow,
              now: _now,
            );
            heroTiming = _heroTimingFor(nextPrayer);
            highlightedPrayer = heroTiming.entry.kind;
          } else {
            heroTiming = _selectedDateHeroTiming(selectedDay);
            highlightedPrayer = null;
          }

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
                        selectedDay,
                        heroTiming,
                        settings,
                        location,
                        isViewingToday,
                      ),
                      const SizedBox(height: 14),
                      _buildPrayerGrid(
                        context,
                        selectedDay,
                        highlightedPrayer,
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
    bool isViewingToday,
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
                    isViewingToday ? 'Next prayer' : 'Selected date',
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
                if (isViewingToday)
                  _InfoPill(
                    icon: Icons.hourglass_bottom_rounded,
                    label: formatPrayerCountdownLabel(
                      heroTiming.countdown,
                      isNow: heroTiming.isNow,
                    ),
                  ),
                _DateInfoPill(
                  icon: Icons.calendar_today_rounded,
                  label: _formatDate(day.date),
                  tooltip: 'Select date',
                  onTap: () => _selectPrayerDate(day.date),
                  onClear: isViewingToday ? null : _returnToToday,
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
            Row(
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
              ],
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
    PrayerTimeKind? highlightedKind,
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
              isNext: highlightedKind != null && entry.kind == highlightedKind,
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
      await _rescheduleReminders(location);
      if (!mounted) return;
      _showMessage('Location saved.');
      return;
    }

    _showLocationError(result);
  }

  Future<void> _refreshCurrentDeviceLocationOnEntry() async {
    final PrayerLocation? savedLocation = _store.getLocation();
    if (savedLocation?.mode != PrayerLocationMode.currentDevice) return;

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
      _showLocationError(result);
      return;
    }

    await _store.saveLocation(location);
    await _rescheduleReminders(location);
  }

  Future<void> _chooseManually(PrayerLocation? initialLocation) async {
    final PrayerLocation? location = await Navigator.of(context).push(
      MaterialPageRoute<PrayerLocation>(
        builder: (BuildContext context) =>
            ManualPrayerLocationPage(initialLocation: initialLocation),
      ),
    );
    if (location == null) return;
    await _saveResolvedLocation(location);
    if (!mounted) return;
    _showMessage('Location saved.');
  }

  Future<void> _chooseOnMap(PrayerLocation? initialLocation) async {
    final PrayerLocationPicker picker =
        widget.mapLocationPicker ?? showPrayerMapLocationPicker;
    final PrayerLocation? location = await picker(context, initialLocation);
    if (location == null) return;
    await _saveResolvedLocation(location);
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
          onSave: (_LocationDetailsSave detailsSave) async {
            await _saveResolvedLocation(
              detailsSave.location,
              previousLocation: location,
              preserveCustomLabel: detailsSave.preserveCustomLabel,
            );
            if (!mounted || !sheetContext.mounted) return;
            Navigator.of(sheetContext).pop();
            _showMessage('Location saved.');
          },
        );
      },
    );
  }

  Future<void> _saveResolvedLocation(
    PrayerLocation location, {
    PrayerLocation? previousLocation,
    bool preserveCustomLabel = false,
  }) async {
    final PrayerLocation resolvedLocation = await _locationService
        .resolveLocationForSave(
          location,
          previousLocation: previousLocation ?? _store.getLocation(),
          preserveCustomLabel: preserveCustomLabel,
        );
    await _store.saveLocation(resolvedLocation);
    await _rescheduleReminders(resolvedLocation);
  }

  Future<void> _rescheduleReminders(PrayerLocation location) async {
    final PrayerTimeSettings settings = _store.getSettings();
    final PrayerNotificationScheduleResult result = await _notificationService
        .reschedule(settings: settings, location: location);
    if (result.status == PrayerNotificationScheduleStatus.permissionDenied &&
        settings.reminderSettings.remindersEnabled) {
      await _store.saveSettings(
        settings.copyWith(
          reminderSettings: settings.reminderSettings.copyWith(
            remindersEnabled: false,
          ),
        ),
      );
      if (!mounted) return;
      _showMessage('Notification permission is off. Reminders were disabled.');
    }
  }

  void _openPrayerSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const PrayerTimesSettingsPage(),
      ),
    );
  }

  Future<void> _selectPrayerDate(DateTime currentDate) async {
    final DateTime initialDate = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select prayer date',
    );
    if (pickedDate == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  void _returnToToday() {
    setState(() {
      _selectedDate = null;
    });
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

_PrayerHeroTiming _selectedDateHeroTiming(PrayerDay day) {
  return _PrayerHeroTiming(
    entry: day.entryFor(PrayerTimeKind.fajr),
    countdown: Duration.zero,
    isNow: false,
  );
}

bool _isSameCalendarDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
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
  final Future<void> Function(_LocationDetailsSave location) onSave;

  @override
  State<_LocationDetailsSheet> createState() => _LocationDetailsSheetState();
}

class _LocationDetailsSheetState extends State<_LocationDetailsSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final String _initialLabel;
  late final String _initialLatitudeText;
  late final String _initialLongitudeText;
  bool _advancedExpanded = false;
  bool _hasFieldChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initialLabel = widget.location.displayLabel;
    _initialLatitudeText = widget.location.latitude.toStringAsFixed(6);
    _initialLongitudeText = widget.location.longitude.toStringAsFixed(6);
    _labelController = TextEditingController(text: _initialLabel);
    _latitudeController = TextEditingController(text: _initialLatitudeText);
    _longitudeController = TextEditingController(text: _initialLongitudeText);
    _labelController.addListener(_updateFieldChanges);
    _latitudeController.addListener(_updateFieldChanges);
    _longitudeController.addListener(_updateFieldChanges);
  }

  @override
  void dispose() {
    _labelController.removeListener(_updateFieldChanges);
    _latitudeController.removeListener(_updateFieldChanges);
    _longitudeController.removeListener(_updateFieldChanges);
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
              _SavedLocationPanel(location: widget.location),
              const SizedBox(height: 14),
              _LocationActionRow(
                icon: Icons.my_location_rounded,
                title: 'Update current location',
                subtitle: 'Use this device location',
                onTap: widget.isLocating || _isSaving
                    ? null
                    : widget.onUpdateCurrentLocation,
              ),
              const SizedBox(height: 8),
              _LocationActionRow(
                icon: Icons.map_outlined,
                title: 'Choose on map',
                subtitle: 'Move the map pin to a place',
                onTap: _isSaving ? null : widget.onChooseMap,
              ),
              const SizedBox(height: 14),
              _buildAdvancedCoordinates(context),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _advancedExpanded
                    ? Padding(
                        key: const ValueKey<String>('save-location-changes'),
                        padding: const EdgeInsets.only(top: 14),
                        child: FilledButton.icon(
                          onPressed: _isSaving || !_hasFieldChanges
                              ? null
                              : _save,
                          icon: _isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text('Save changes'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedCoordinates(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded: _advancedExpanded,
          maintainState: true,
          onExpansionChanged: (bool expanded) {
            setState(() {
              _advancedExpanded = expanded;
            });
          },
          leading: Icon(Icons.tune_rounded, color: colors.primary),
          title: Text(
            'Advanced coordinates',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: _advancedExpanded
              ? null
              : Text(
                  'Edit only if you need precise coordinates',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
          children: <Widget>[
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
              validator: _advancedExpanded
                  ? (String? value) => validatePrayerCoordinate(
                      value,
                      min: -90,
                      max: 90,
                      label: 'Latitude',
                    )
                  : null,
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
              validator: _advancedExpanded
                  ? (String? value) => validatePrayerCoordinate(
                      value,
                      min: -180,
                      max: 180,
                      label: 'Longitude',
                    )
                  : null,
              onFieldSubmitted: (_) {
                if (_hasFieldChanges) _save();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_advancedExpanded && !_hasFieldChanges) return;
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
    final bool labelChanged = label != _initialLabel;

    await widget.onSave(
      _LocationDetailsSave(
        location: PrayerLocation(
          latitude: latitude,
          longitude: longitude,
          label: coordinatesChanged && !labelChanged ? 'Saved location' : label,
          mode: coordinatesChanged
              ? PrayerLocationMode.manual
              : widget.location.mode,
          countryCode: coordinatesChanged ? null : widget.location.countryCode,
          timezoneId: coordinatesChanged ? null : widget.location.timezoneId,
        ),
        preserveCustomLabel: labelChanged,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
  }

  void _updateFieldChanges() {
    final bool hasChanges =
        _labelController.text.trim() != _initialLabel ||
        _latitudeController.text.trim() != _initialLatitudeText ||
        _longitudeController.text.trim() != _initialLongitudeText;
    if (hasChanges == _hasFieldChanges) return;
    setState(() {
      _hasFieldChanges = hasChanges;
    });
  }
}

class _LocationDetailsSave {
  const _LocationDetailsSave({
    required this.location,
    required this.preserveCustomLabel,
  });

  final PrayerLocation location;
  final bool preserveCustomLabel;
}

class _SavedLocationPanel extends StatelessWidget {
  const _SavedLocationPanel({required this.location});

  final PrayerLocation location;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.place_outlined, color: colors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    location.displayLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _locationPrivacyText(location),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _locationPrivacyText(PrayerLocation location) {
  final String? timezoneId = location.timezoneId;
  final String timezoneText = timezoneId == null || timezoneId.isEmpty
      ? ''
      : ' Timezone: $timezoneId.';
  return 'Used locally for prayer-time calculation. Coordinates are stored on this device.$timezoneText';
}

class _LocationActionRow extends StatelessWidget {
  const _LocationActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool enabled = onTap != null;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: Border.all(color: colors.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer.withValues(
                    alpha: enabled ? 0.58 : 0.28,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: enabled ? null : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
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
  const _InfoPill({
    required this.icon,
    required this.label,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(AppRadii.small);
    final Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.66),
        borderRadius: borderRadius,
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
    final VoidCallback? onTap = this.onTap;
    if (onTap == null) return pill;
    return Tooltip(
      message: tooltip ?? label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: borderRadius, onTap: onTap, child: pill),
      ),
    );
  }
}

class _DateInfoPill extends StatelessWidget {
  const _DateInfoPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(AppRadii.small);
    final VoidCallback? onClear = this.onClear;

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.66),
          borderRadius: borderRadius,
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Tooltip(
              message: tooltip ?? label,
              child: InkWell(
                borderRadius: onClear == null
                    ? borderRadius
                    : BorderRadius.only(
                        topLeft: Radius.circular(AppRadii.small),
                        bottomLeft: Radius.circular(AppRadii.small),
                      ),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    11,
                    8,
                    onClear == null ? 11 : 7,
                    8,
                  ),
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
              ),
            ),
            if (onClear != null) ...<Widget>[
              SizedBox(
                height: 22,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              Tooltip(
                message: 'Return to today',
                child: InkWell(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(AppRadii.small),
                    bottomRight: Radius.circular(AppRadii.small),
                  ),
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 8,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
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
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
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
