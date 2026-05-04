import 'dart:async';

import 'package:equran/backend/settings_db.dart';
import 'package:equran/prayer/manual_prayer_location_page.dart';
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
  });

  final bool enableLiveCountdown;
  final DateTime? initialNow;

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
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
        });
      });
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
                        nextPrayer,
                        settings,
                        location,
                      ),
                      const SizedBox(height: 14),
                      _buildPrayerGrid(context, today, nextPrayer, settings),
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
    NextPrayer nextPrayer,
    PrayerTimeSettings settings,
    PrayerLocation location,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final String methodLabel = settings.method == PrayerCalculationMethod.auto
        ? '${day.effectiveMethod.label} (auto)'
        : day.effectiveMethod.label;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    Icons.mosque_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        location.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${location.mode.label} • ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Prayer settings',
                  onPressed: _openPrayerSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
                IconButton(
                  tooltip: 'Change location',
                  onPressed: () => _chooseManually(location),
                  icon: const Icon(Icons.edit_location_alt_outlined),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Next prayer',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: <Widget>[
                Text(
                  nextPrayer.entry.kind.label,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.02,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    _formatTime(
                      nextPrayer.entry.time,
                      settings.use24HourFormat,
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _InfoPill(
                  icon: Icons.hourglass_bottom_rounded,
                  label: _formatCountdown(nextPrayer.countdown),
                ),
                _InfoPill(
                  icon: Icons.calendar_today_rounded,
                  label: _formatDate(day.date),
                ),
                _InfoPill(icon: Icons.calculate_outlined, label: methodLabel),
              ],
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
              'Choose your location to calculate prayer times',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prayer times are calculated locally on your device after you select a location.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
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
                  onPressed: () => _chooseManually(null),
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Choose manually'),
                ),
                IconButton(
                  tooltip: 'Prayer settings',
                  onPressed: _openPrayerSettings,
                  icon: const Icon(Icons.tune_rounded),
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
    NextPrayer nextPrayer,
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
              isNext: entry.kind == nextPrayer.entry.kind,
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

    _showMessage(result.message ?? 'Unable to get location.');
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
                  if (entry.offsetMinutes != 0) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      'Manual offset ${entry.offsetMinutes > 0 ? '+' : ''}${entry.offsetMinutes} min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
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

String _formatCountdown(Duration duration) {
  final Duration safeDuration = duration.isNegative ? Duration.zero : duration;
  final int hours = safeDuration.inHours;
  final int minutes = safeDuration.inMinutes.remainder(60);
  final int seconds = safeDuration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${_two(minutes)}m ${_two(seconds)}s';
  }
  return '${minutes}m ${_two(seconds)}s';
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
