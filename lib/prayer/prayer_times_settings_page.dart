import 'dart:async';

import 'package:equran/prayer/manual_prayer_location_page.dart';
import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_map_location_page.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_notification_service.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/prayer/prayer_times_service.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:equran/widgets/app_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrayerTimesSettingsPage extends StatefulWidget {
  const PrayerTimesSettingsPage({super.key});

  @override
  State<PrayerTimesSettingsPage> createState() =>
      _PrayerTimesSettingsPageState();
}

class _PrayerTimesSettingsPageState extends State<PrayerTimesSettingsPage>
    with WidgetsBindingObserver {
  final PrayerSettingsStore _store = PrayerSettingsStore();
  final PrayerLocationService _locationService = const PrayerLocationService();
  final PrayerNotificationService _notificationService =
      PrayerNotificationService();
  final PrayerTimesService _service = const PrayerTimesService();
  late PrayerTimeSettings _settings;
  PrayerLocation? _location;
  bool _isLocating = false;
  bool _isUpdatingReminders = false;
  bool _isCheckingNotificationPermission = false;
  bool _notificationPermissionRequestAttempted = false;
  bool _notificationPermissionHasError = false;
  PrayerNotificationPermissionStatus? _notificationPermission;
  String? _notificationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings = _store.getSettings();
    _location = _store.getLocation();
    _refreshNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationPermission(rescheduleIfGranted: true);
    }
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
                  "Save this device's location for prayer calculations.",
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
                leading: const Icon(Icons.map_outlined),
                title: const Text('Choose on map'),
                subtitle: const Text('Move the map under a centered pin.'),
                onTap: () => _chooseOnMap(_location),
              ),
              ListTile(
                leading: const Icon(Icons.edit_location_alt_outlined),
                title: const Text('Enter coordinates manually'),
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
          _buildPrayerRemindersSection(context),
          _buildSettingsGroup(
            context: context,
            title: 'Calculation',
            subtitle: _calculationSubtitle,
            icon: Icons.calculate_outlined,
            children: <Widget>[
              ListTile(
                title: const Text('Calculation method'),
                subtitle: Text(_methodSubtitle),
                onTap: _selectCalculationMethod,
              ),
              ListTile(
                title: const Text('Asr method'),
                subtitle: Text(_settings.asrMethod.label),
                onTap: _selectAsrMethod,
              ),
              ListTile(
                title: const Text('High latitude adjustment'),
                subtitle: Text(
                  '${_settings.highLatitudeRule.label}\n'
                  'Used when Fajr or Isha are difficult to calculate in far northern or southern locations.',
                ),
                isThreeLine: true,
                onTap: _selectHighLatitudeRule,
              ),
              ListTile(
                title: const Text('Time format'),
                subtitle: Text(
                  _settings.use24HourFormat ? '24-hour' : '12-hour',
                ),
                onTap: _selectTimeFormat,
              ),
              SwitchListTile(
                title: const Text('Use location timezone'),
                subtitle: Text(_timezoneSettingSubtitle),
                value: _settings.useLocationTimezone,
                onChanged: (bool enabled) => _saveSettings(
                  _settings.copyWith(useLocationTimezone: enabled),
                ),
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

  Widget _buildPrayerRemindersSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final PrayerReminderSettings reminders = _settings.reminderSettings;
    final bool remindersOn = reminders.remindersEnabled;
    final PrayerNotificationPermissionStatus? permission =
        _notificationPermission;
    final bool permissionOff =
        permission == PrayerNotificationPermissionStatus.denied ||
        permission == PrayerNotificationPermissionStatus.unsupported;

    return _buildSettingsGroup(
      context: context,
      title: 'Prayer Reminders',
      subtitle: _reminderSubtitle,
      icon: Icons.notifications_active_outlined,
      children: <Widget>[
        SwitchListTile(
          secondary: _isUpdatingReminders
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_none_rounded),
          title: const Text('Prayer reminders'),
          subtitle: Text(_notificationPermissionSubtitle),
          value: remindersOn,
          onChanged: _isUpdatingReminders ? null : _toggleGlobalReminders,
        ),
        if (permissionOff || _notificationMessage != null)
          _buildNotificationPermissionBanner(theme),
        if (remindersOn && _location == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Choose a location before reminders can be scheduled.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: <Widget>[
              for (final PrayerTimeKind prayer in PrayerTimeKind.reminderOrder)
                SwitchListTile(
                  title: Text(prayer.label),
                  subtitle: const Text('Notify at the saved prayer time.'),
                  value: reminders.prayerToggleFor(prayer),
                  onChanged: _isUpdatingReminders
                      ? null
                      : (bool enabled) =>
                            _togglePrayerReminder(prayer, enabled),
                ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Reminder time'),
                subtitle: Text(
                  _reminderOffsetLabel(reminders.reminderOffsetMinutes),
                ),
                enabled: !_isUpdatingReminders,
                onTap: _isUpdatingReminders ? null : _selectReminderOffset,
              ),
            ],
          ),
          crossFadeState: remindersOn
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }

  Widget _buildNotificationPermissionBanner(ThemeData theme) {
    final ColorScheme colors = theme.colorScheme;
    final PrayerNotificationPermissionStatus? permission =
        _notificationPermission;
    final bool unsupported =
        permission == PrayerNotificationPermissionStatus.unsupported;
    final bool error = _notificationPermissionHasError;
    final bool openSettings =
        permission == PrayerNotificationPermissionStatus.denied &&
        _notificationPermissionRequestAttempted;
    final VoidCallback action = error
        ? () => _refreshNotificationPermission()
        : openSettings
        ? _openNotificationSettings
        : _requestNotificationPermission;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: colors.error.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.notifications_off_outlined,
                    color: colors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _notificationMessage ??
                          'Notification permission is off. Enable it to receive prayer reminders.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!unsupported)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _isUpdatingReminders ? null : action,
                    icon: Icon(
                      error
                          ? Icons.refresh_rounded
                          : openSettings
                          ? Icons.settings_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    label: Text(
                      error
                          ? 'Retry'
                          : openSettings
                          ? 'Open app settings'
                          : 'Request permission',
                    ),
                  ),
                ),
            ],
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'Some high-latitude mosque timetables use fixed or capped Isha times during summer.',
                ),
              ),
            ),
            ListTile(
              title: const Text('Isha mode'),
              subtitle: Text(_settings.customIshaMode.label),
              onTap: _selectCustomIshaMode,
            ),
            ..._buildCustomIshaFields(),
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
                max: 30,
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

  List<Widget> _buildCustomIshaFields() {
    return switch (_settings.customIshaMode) {
      PrayerCustomIshaMode.angle => <Widget>[_buildCustomIshaAngleTile()],
      PrayerCustomIshaMode.interval => <Widget>[
        _buildCustomIshaIntervalTile(requiredValue: true),
      ],
      PrayerCustomIshaMode.fixedTime => <Widget>[
        ListTile(
          title: const Text('Fixed Isha time'),
          subtitle: Text(
            _clockLabel(
              _settings.customIshaFixedTimeHour,
              _settings.customIshaFixedTimeMinute,
            ),
          ),
          onTap: () => _editCustomIshaClockTime(
            title: 'Fixed Isha time',
            initialHour: _settings.customIshaFixedTimeHour,
            initialMinute: _settings.customIshaFixedTimeMinute,
            onChanged: (TimeOfDay value) => _saveSettings(
              _settings.copyWith(
                customIshaFixedTimeHour: value.hour,
                customIshaFixedTimeMinute: value.minute,
              ),
            ),
          ),
        ),
      ],
      PrayerCustomIshaMode.latestCap => <Widget>[
        _buildCustomIshaAngleTile(title: 'Base Isha angle'),
        _buildCustomIshaIntervalTile(requiredValue: false),
        ListTile(
          title: const Text('Latest Isha time'),
          subtitle: Text(
            'Use calculated Isha, but do not allow it later than '
            '${_clockLabel(_settings.customIshaLatestCapHour, _settings.customIshaLatestCapMinute)}.',
          ),
          onTap: () => _editCustomIshaClockTime(
            title: 'Latest Isha time',
            initialHour: _settings.customIshaLatestCapHour,
            initialMinute: _settings.customIshaLatestCapMinute,
            onChanged: (TimeOfDay value) => _saveSettings(
              _settings.copyWith(
                customIshaLatestCapHour: value.hour,
                customIshaLatestCapMinute: value.minute,
              ),
            ),
          ),
        ),
      ],
    };
  }

  Widget _buildCustomIshaAngleTile({String title = 'Isha angle'}) {
    return ListTile(
      title: Text(title),
      subtitle: Text('${_settings.customIshaAngle.toStringAsFixed(1)}°'),
      onTap: () => _editDoubleSetting(
        title: title,
        currentValue: _settings.customIshaAngle,
        min: 0,
        max: 30,
        suffix: 'degrees',
        onChanged: (double value) =>
            _saveSettings(_settings.copyWith(customIshaAngle: value)),
      ),
    );
  }

  Widget _buildCustomIshaIntervalTile({required bool requiredValue}) {
    return ListTile(
      title: Text(requiredValue ? 'Isha interval' : 'Base Isha interval'),
      subtitle: Text(
        _settings.customIshaInterval == null
            ? 'Use Isha angle'
            : '${_settings.customIshaInterval} minutes after Maghrib',
      ),
      onTap: () => requiredValue
          ? _editIntSetting(
              title: 'Isha interval',
              currentValue: _settings.customIshaInterval ?? 90,
              min: 0,
              max: 240,
              suffix: 'minutes',
              onChanged: (int value) =>
                  _saveSettings(_settings.withCustomIshaInterval(value)),
            )
          : _editOptionalIntSetting(
              title: 'Base Isha interval',
              currentValue: _settings.customIshaInterval,
              min: 0,
              max: 240,
              emptyLabel: 'Leave blank to use the base Isha angle.',
              onChanged: (int? value) =>
                  _saveSettings(_settings.withCustomIshaInterval(value)),
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

  Future<void> _selectHighLatitudeRule() async {
    final PrayerHighLatitudeRule? selected =
        await _showSelectionDialog<PrayerHighLatitudeRule>(
          title: 'High Latitude Adjustment',
          icon: Icons.public_rounded,
          selectedValue: _settings.highLatitudeRule,
          options: PrayerHighLatitudeRule.values
              .map(
                (PrayerHighLatitudeRule rule) =>
                    AppSelectionOption<PrayerHighLatitudeRule>(
                      value: rule,
                      title: rule.label,
                      subtitle: switch (rule) {
                        PrayerHighLatitudeRule.auto =>
                          'Apply a rule only for high-latitude locations.',
                        PrayerHighLatitudeRule.none =>
                          'Do not apply a high-latitude rule.',
                        PrayerHighLatitudeRule.middleOfTheNight =>
                          'Cap Fajr and Isha using the middle of the night.',
                        PrayerHighLatitudeRule.oneSeventh =>
                          'Use one seventh of the night.',
                        PrayerHighLatitudeRule.angleBased =>
                          'Use the Fajr and Isha angles as the night fraction.',
                      },
                    ),
              )
              .toList(),
        );
    if (selected == null) return;
    await _saveSettings(_settings.copyWith(highLatitudeRule: selected));
  }

  Future<void> _selectCustomIshaMode() async {
    final PrayerCustomIshaMode? selected =
        await _showSelectionDialog<PrayerCustomIshaMode>(
          title: 'Isha Mode',
          icon: Icons.dark_mode_outlined,
          selectedValue: _settings.customIshaMode,
          options: PrayerCustomIshaMode.values
              .map(
                (PrayerCustomIshaMode mode) =>
                    AppSelectionOption<PrayerCustomIshaMode>(
                      value: mode,
                      title: mode.label,
                      subtitle: switch (mode) {
                        PrayerCustomIshaMode.angle =>
                          'Use the custom Isha angle.',
                        PrayerCustomIshaMode.interval =>
                          'Set Isha a fixed number of minutes after Maghrib.',
                        PrayerCustomIshaMode.fixedTime =>
                          'Use the same clock time on each selected prayer date.',
                        PrayerCustomIshaMode.latestCap =>
                          'Use calculated Isha unless it goes later than a cap.',
                      },
                    ),
              )
              .toList(),
        );
    if (selected == null) return;
    PrayerTimeSettings settings = _settings.copyWith(customIshaMode: selected);
    if (selected == PrayerCustomIshaMode.interval &&
        settings.customIshaInterval == null) {
      settings = settings.copyWith(customIshaInterval: 90);
    }
    await _saveSettings(settings);
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

  Future<void> _toggleGlobalReminders(bool enabled) async {
    final PrayerReminderSettings reminders = _settings.reminderSettings;
    if (!enabled) {
      await _saveReminderSettings(reminders.copyWith(remindersEnabled: false));
      return;
    }

    setState(() {
      _isUpdatingReminders = true;
      _notificationMessage = null;
      _notificationPermissionHasError = false;
    });
    try {
      final PrayerNotificationPermissionStatus permission =
          await _notificationService.requestPermission();
      if (!mounted) return;
      setState(() {
        _notificationPermission = permission;
        _notificationPermissionRequestAttempted = true;
        _notificationPermissionHasError = false;
      });

      if (permission != PrayerNotificationPermissionStatus.granted) {
        await _notificationService.cancelPrayerNotifications();
        if (!mounted) return;
        setState(() {
          _notificationMessage = _notificationMessageForPermission(permission);
        });
        _showMessage(
          permission == PrayerNotificationPermissionStatus.unsupported
              ? 'Prayer reminders are not supported on this platform.'
              : 'Notification permission is off. Prayer reminders were not enabled.',
        );
        return;
      }

      await _saveReminderSettings(reminders.copyWith(remindersEnabled: true));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _notificationPermissionHasError = true;
        _notificationMessage =
            'Notification permission request timed out. Try reopening the app or enabling notifications in system settings.';
      });
      _showMessage('Notification permission request timed out.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationPermissionHasError = true;
        _notificationMessage =
            'Could not request notification permission. Try again or enable notifications in system settings.';
      });
      _showMessage('Could not request notification permission.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingReminders = false;
        });
      }
    }
  }

  Future<void> _togglePrayerReminder(
    PrayerTimeKind prayer,
    bool enabled,
  ) async {
    setState(() {
      _isUpdatingReminders = true;
    });
    try {
      await _saveReminderSettings(
        _settings.reminderSettings.copyWithPrayer(prayer, enabled),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingReminders = false;
        });
      }
    }
  }

  Future<void> _selectReminderOffset() async {
    final int? selected = await _showSelectionDialog<int>(
      title: 'Reminder Time',
      icon: Icons.schedule_rounded,
      selectedValue: _settings.reminderSettings.reminderOffsetMinutes,
      options: const <AppSelectionOption<int>>[
        AppSelectionOption<int>(value: 0, title: 'At prayer time'),
        AppSelectionOption<int>(value: 5, title: '5 minutes before'),
        AppSelectionOption<int>(value: 10, title: '10 minutes before'),
        AppSelectionOption<int>(value: 15, title: '15 minutes before'),
        AppSelectionOption<int>(value: 30, title: '30 minutes before'),
      ],
    );
    if (selected == null) return;
    setState(() {
      _isUpdatingReminders = true;
    });
    try {
      await _saveReminderSettings(
        _settings.reminderSettings.copyWith(reminderOffsetMinutes: selected),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingReminders = false;
        });
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() {
      _isUpdatingReminders = true;
      _notificationMessage = null;
      _notificationPermissionHasError = false;
    });
    try {
      final PrayerNotificationPermissionStatus permission =
          await _notificationService.requestPermission();
      if (!mounted) return;
      setState(() {
        _notificationPermission = permission;
        _notificationPermissionRequestAttempted = true;
        _notificationPermissionHasError = false;
        _notificationMessage = _notificationMessageForPermission(permission);
      });
      if (permission == PrayerNotificationPermissionStatus.granted &&
          _settings.reminderSettings.remindersEnabled) {
        await _saveSettings(_settings);
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _notificationPermissionHasError = true;
        _notificationMessage =
            'Notification permission request timed out. Try reopening the app or enabling notifications in system settings.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationPermissionHasError = true;
        _notificationMessage =
            'Could not request notification permission. Try again or enable notifications in system settings.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingReminders = false;
        });
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    setState(() {
      _notificationPermissionRequestAttempted = true;
      _notificationPermissionHasError = false;
    });
    try {
      await _notificationService.openSettings();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _notificationPermissionHasError = true;
        _notificationMessage =
            'Opening notification settings timed out. Open Android app settings manually and enable notifications.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationPermissionHasError = true;
        _notificationMessage =
            'Could not open notification settings. Open Android app settings manually and enable notifications.';
      });
    }
  }

  Future<void> _saveReminderSettings(
    PrayerReminderSettings reminderSettings,
  ) async {
    final PrayerTimeSettings settings = _settings.copyWith(
      reminderSettings: reminderSettings,
    );
    await _saveSettings(settings);
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
    final int? value = await _showSteppedIntDialog(
      title: '${prayer.label} offset',
      currentValue: _settings.offsets.forPrayer(prayer),
      min: -120,
      max: 120,
      helperText:
          'Type minutes as digits only. Use - and + to adjust before or after the calculated time.',
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

  Future<void> _editIntSetting({
    required String title,
    required int currentValue,
    required int min,
    required int max,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) async {
    final int? value = await _showSteppedIntDialog(
      title: title,
      currentValue: currentValue,
      min: min,
      max: max,
      helperText:
          'Type $suffix as digits only. Use - and + to adjust the value.',
    );
    if (value == null) return;
    onChanged(value);
  }

  Future<void> _editCustomIshaClockTime({
    required String title,
    required int initialHour,
    required int initialMinute,
    required ValueChanged<TimeOfDay> onChanged,
  }) async {
    final TimeOfDay? value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      helpText: title,
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
        await _showOptionalSteppedIntDialog(
          title: title,
          currentValue: currentValue,
          min: min,
          max: max,
          helperText:
              '$emptyLabel Blank saves 0. Type digits only and use - or + to adjust.',
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

  Future<int?> _showSteppedIntDialog({
    required String title,
    required int currentValue,
    required int min,
    required int max,
    required String helperText,
  }) {
    return _showSteppedIntDialogInternal(
      title: title,
      currentValue: currentValue,
      min: min,
      max: max,
      helperText: helperText,
      allowNullValue: false,
    ).then((value) => value?.value);
  }

  Future<_OptionalNumberResult<int>?> _showOptionalSteppedIntDialog({
    required String title,
    required int? currentValue,
    required int min,
    required int max,
    required String helperText,
  }) {
    return _showSteppedIntDialogInternal(
      title: title,
      currentValue: currentValue,
      min: min,
      max: max,
      helperText: helperText,
      allowNullValue: true,
    );
  }

  Future<_OptionalNumberResult<int>?> _showSteppedIntDialogInternal({
    required String title,
    required int? currentValue,
    required int min,
    required int max,
    required String helperText,
    required bool allowNullValue,
  }) {
    int signedValue = (currentValue ?? 0).clamp(min, max).toInt();
    final TextEditingController controller = TextEditingController(
      text: currentValue == null ? '' : signedValue.abs().toString(),
    );

    int signedValueFromText() {
      final String raw = controller.text.trim();
      final int magnitude = raw.isEmpty ? 0 : int.tryParse(raw) ?? -1;
      if (magnitude < 0) return min - 1;
      if (signedValue < 0 && min < 0) return -magnitude;
      return magnitude;
    }

    void setControllerText(int value) {
      controller.value = TextEditingValue(
        text: value.abs().toString(),
        selection: TextSelection.collapsed(
          offset: value.abs().toString().length,
        ),
      );
    }

    return showDialog<_OptionalNumberResult<int>?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            void stepBy(int delta) {
              final int fromText = signedValueFromText();
              if (fromText >= min && fromText <= max) {
                signedValue = fromText;
              }
              setDialogState(() {
                signedValue = (signedValue + delta).clamp(min, max).toInt();
                setControllerText(signedValue);
              });
            }

            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton.filledTonal(
                        tooltip: 'Decrease',
                        onPressed: () => stepBy(-1),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            helperText: helperText,
                            prefixText: signedValue < 0 ? '-' : null,
                          ),
                          onChanged: (_) {
                            setDialogState(() {
                              final int fromText = signedValueFromText();
                              if (fromText >= min && fromText <= max) {
                                signedValue = fromText;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Increase',
                        onPressed: () => stepBy(1),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                if (allowNullValue)
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _OptionalNumberResult<Never>(null)),
                    child: const Text('Clear'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final int value = signedValueFromText();
                    if (value < min || value > max) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Enter a value from $min to $max.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(_OptionalNumberResult<int>(value));
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
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
      _showLocationError(result);
      return;
    }
    final PrayerLocation resolvedLocation = await _saveResolvedLocation(
      location,
    );
    if (!mounted) return;
    setState(() {
      _location = resolvedLocation;
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
    final PrayerLocation resolvedLocation = await _saveResolvedLocation(
      location,
    );
    if (!mounted) return;
    setState(() {
      _location = resolvedLocation;
    });
    _showMessage('Location saved.');
  }

  Future<void> _chooseOnMap(PrayerLocation? initialLocation) async {
    final PrayerLocation? location = await showPrayerMapLocationPicker(
      context,
      initialLocation,
    );
    if (location == null) return;
    final PrayerLocation resolvedLocation = await _saveResolvedLocation(
      location,
    );
    if (!mounted) return;
    setState(() {
      _location = resolvedLocation;
    });
    _showMessage('Location saved.');
  }

  Future<PrayerLocation> _saveResolvedLocation(PrayerLocation location) async {
    final PrayerLocation resolvedLocation = await _locationService
        .resolveLocationForSave(location, previousLocation: _location);
    await _store.saveLocation(resolvedLocation);
    await _rescheduleReminders(location: resolvedLocation);
    return resolvedLocation;
  }

  Future<void> _clearLocation() async {
    await _store.clearLocation();
    await _rescheduleReminders(locationCleared: true);
    if (!mounted) return;
    setState(() {
      _location = null;
    });
    _showMessage('Location cleared.');
  }

  Future<void> _saveSettings(PrayerTimeSettings settings) async {
    await _store.saveSettings(settings);
    final PrayerNotificationScheduleResult reminderResult =
        await _rescheduleReminders(settings: settings);
    PrayerTimeSettings savedSettings = settings;
    final bool permissionBlocked =
        settings.reminderSettings.remindersEnabled &&
        (reminderResult.status ==
                PrayerNotificationScheduleStatus.permissionDenied ||
            reminderResult.status ==
                PrayerNotificationScheduleStatus.unsupported);
    if (permissionBlocked) {
      savedSettings = settings.copyWith(
        reminderSettings: settings.reminderSettings.copyWith(
          remindersEnabled: false,
        ),
      );
      await _store.saveSettings(savedSettings);
      if (mounted) {
        setState(() {
          _notificationPermission =
              reminderResult.status ==
                  PrayerNotificationScheduleStatus.unsupported
              ? PrayerNotificationPermissionStatus.unsupported
              : PrayerNotificationPermissionStatus.denied;
          _notificationMessage = _notificationMessageForPermission(
            _notificationPermission!,
          );
        });
        _showMessage(
          reminderResult.status == PrayerNotificationScheduleStatus.unsupported
              ? 'Prayer reminders are not supported on this platform.'
              : 'Notification permission is off. Reminders were disabled.',
        );
      }
    } else if (reminderResult.status == PrayerNotificationScheduleStatus.failed) {
      if (mounted) {
        setState(() {
          _notificationMessage =
              reminderResult.message ?? 'Prayer reminders could not be scheduled.';
        });
        _showMessage(_notificationMessage!);
      }
    } else if (reminderResult.status ==
        PrayerNotificationScheduleStatus.scheduled) {
      if (mounted) {
        setState(() {
          _notificationPermission = PrayerNotificationPermissionStatus.granted;
          _notificationMessage = null;
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _settings = savedSettings;
    });
  }

  Future<PrayerNotificationScheduleResult> _rescheduleReminders({
    PrayerTimeSettings? settings,
    PrayerLocation? location,
    bool locationCleared = false,
  }) async {
    return _notificationService.reschedule(
      settings: settings ?? _settings,
      location: locationCleared ? null : location ?? _location,
    );
  }

  Future<void> _refreshNotificationPermission({
    bool rescheduleIfGranted = false,
  }) async {
    setState(() {
      _isCheckingNotificationPermission = true;
    });
    try {
      final PrayerNotificationPermissionStatus permission =
          await _notificationService.checkPermission();
      if (!mounted) return;
      final bool showDeniedMessage =
          permission == PrayerNotificationPermissionStatus.denied &&
          _settings.reminderSettings.remindersEnabled;
      setState(() {
        _notificationPermission = permission;
        _notificationPermissionHasError = false;
        if (permission == PrayerNotificationPermissionStatus.granted) {
          _notificationPermissionRequestAttempted = false;
        }
        _notificationMessage =
            showDeniedMessage ||
                permission == PrayerNotificationPermissionStatus.unsupported
            ? _notificationMessageForPermission(permission)
            : null;
      });
      if (permission == PrayerNotificationPermissionStatus.granted &&
          rescheduleIfGranted &&
          _settings.reminderSettings.remindersEnabled) {
        await _rescheduleReminders();
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _notificationPermissionHasError = true;
        _notificationMessage =
            'Notification permission check timed out. Try reopening the app or enabling notifications in system settings.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationPermissionHasError = true;
        _notificationMessage =
            'Could not check notification permission. Try again or enable notifications in system settings.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingNotificationPermission = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _locationSubtitle {
    final PrayerLocation? location = _location;
    if (location == null) return 'Choose a location before calculating';
    return location.displayLabel;
  }

  String get _calculationSubtitle {
    return _methodSubtitle;
  }

  String get _timezoneSettingSubtitle {
    if (!_settings.useLocationTimezone) {
      return 'Using this device timezone.';
    }
    final String? timezoneId = _location?.timezoneId;
    if (timezoneId == null || timezoneId.isEmpty) {
      return 'Using device timezone until the location timezone is available.';
    }
    return 'Display prayer times using $timezoneId.';
  }

  String get _reminderSubtitle {
    final PrayerReminderSettings reminders = _settings.reminderSettings;
    if (!reminders.remindersEnabled || reminders.enabledPrayerCount == 0) {
      return 'Reminders off';
    }
    if (_location == null) return 'On, waiting for location';
    final int enabledCount = reminders.enabledPrayerCount;
    if (enabledCount == PrayerTimeKind.reminderOrder.length) {
      return 'All prayer reminders on';
    }
    return '$enabledCount reminders enabled';
  }

  String get _notificationPermissionSubtitle {
    if (_isCheckingNotificationPermission) {
      return 'Checking notification permission...';
    }
    if (_notificationPermissionHasError) {
      return 'Permission status needs a retry.';
    }
    final PrayerNotificationPermissionStatus? permission =
        _notificationPermission;
    return switch (permission) {
      PrayerNotificationPermissionStatus.granted =>
        _settings.reminderSettings.remindersEnabled
        ? 'Local notifications are scheduled on this device.'
        : 'Notification permission granted.',
      PrayerNotificationPermissionStatus.denied =>
        'Notification permission is off.',
      PrayerNotificationPermissionStatus.unsupported =>
        'Prayer reminders are not supported on this platform.',
      null => 'Checking notification permission...',
    };
  }

  String? _notificationMessageForPermission(
    PrayerNotificationPermissionStatus permission,
  ) {
    return switch (permission) {
      PrayerNotificationPermissionStatus.granted => null,
      PrayerNotificationPermissionStatus.denied =>
        'Notification permission is off. Enable it to receive prayer reminders.',
      PrayerNotificationPermissionStatus.unsupported =>
        'Prayer reminders are not supported on this platform.',
    };
  }

  String get _methodSubtitle {
    final PrayerLocation? location = _location;
    if (_settings.method == PrayerCalculationMethod.auto && location == null) {
      return 'Best method after location is saved';
    }
    final PrayerCalculationMethod effectiveMethod =
        _settings.method == PrayerCalculationMethod.auto && location != null
        ? _service.effectiveMethodFor(location: location, settings: _settings)
        : _settings.method;
    return prayerMethodDisplayLabel(
      settings: _settings,
      effectiveMethod: effectiveMethod,
    );
  }

  String _offsetLabel(int offset) {
    if (offset == 0) return 'No manual adjustment';
    return '${offset > 0 ? '+' : ''}$offset minutes';
  }

  String _reminderOffsetLabel(int offset) {
    if (offset == 0) return 'At prayer time';
    return '$offset minutes before prayer';
  }

  String _clockLabel(int hour, int minute) {
    final TimeOfDay time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
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
      customIshaMode: customIshaMode,
      customIshaInterval: value,
      customIshaFixedTimeHour: customIshaFixedTimeHour,
      customIshaFixedTimeMinute: customIshaFixedTimeMinute,
      customIshaLatestCapHour: customIshaLatestCapHour,
      customIshaLatestCapMinute: customIshaLatestCapMinute,
      customMaghribAngle: customMaghribAngle,
      asrMethod: asrMethod,
      highLatitudeRule: highLatitudeRule,
      offsets: offsets,
      use24HourFormat: use24HourFormat,
      useLocationTimezone: useLocationTimezone,
      reminderSettings: reminderSettings,
    );
  }

  PrayerTimeSettings withCustomMaghribAngle(double? value) {
    return PrayerTimeSettings(
      method: method,
      customFajrAngle: customFajrAngle,
      customIshaAngle: customIshaAngle,
      customIshaMode: customIshaMode,
      customIshaInterval: customIshaInterval,
      customIshaFixedTimeHour: customIshaFixedTimeHour,
      customIshaFixedTimeMinute: customIshaFixedTimeMinute,
      customIshaLatestCapHour: customIshaLatestCapHour,
      customIshaLatestCapMinute: customIshaLatestCapMinute,
      customMaghribAngle: value,
      asrMethod: asrMethod,
      highLatitudeRule: highLatitudeRule,
      offsets: offsets,
      use24HourFormat: use24HourFormat,
      useLocationTimezone: useLocationTimezone,
      reminderSettings: reminderSettings,
    );
  }
}
