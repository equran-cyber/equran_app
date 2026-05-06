import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_timezone_service.dart';
import 'package:timezone/timezone.dart' as timezone;

class PrayerTimesService {
  const PrayerTimesService();

  PrayerDay calculateDay({
    required DateTime date,
    required PrayerLocation location,
    required PrayerTimeSettings settings,
  }) {
    final timezone.Location? prayerTimezone = _prayerTimezoneFor(
      location: location,
      settings: settings,
    );
    final PrayerCalculationMethod effectiveMethod = effectiveMethodFor(
      location: location,
      settings: settings,
    );
    final adhan.HighLatitudeRule highLatitudeRule = resolveHighLatitudeRule(
      location: location,
      settings: settings,
      effectiveMethod: effectiveMethod,
    );
    final adhan.CalculationParameters parameters = _parametersFor(
      method: effectiveMethod,
      settings: settings,
      highLatitudeRule: highLatitudeRule,
    );
    final DateTime localDate = prayerTimezone == null
        ? DateTime(date.year, date.month, date.day)
        : timezone.TZDateTime(prayerTimezone, date.year, date.month, date.day);
    final adhan.PrayerTimes baseTimes = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(location.latitude, location.longitude),
      date: localDate,
      calculationParameters: parameters,
      precision: true,
    );
    final DateTime baseSunrise = _displayTime(
      baseTimes.sunrise,
      prayerTimezone,
    );

    final DateTime baseMaghrib = _displayTime(
      baseTimes.maghrib,
      prayerTimezone,
    );
    final DateTime baseIsha = _displayTime(baseTimes.isha, prayerTimezone);
    final DateTime customIsha = _customIshaTime(
      baseIsha: baseIsha,
      baseMaghrib: baseMaghrib,
      localDate: localDate,
      method: effectiveMethod,
      prayerTimezone: prayerTimezone,
      settings: settings,
    );

    final Map<PrayerTimeKind, DateTime> times = <PrayerTimeKind, DateTime>{
      PrayerTimeKind.fajr: _withOffset(
        _displayTime(baseTimes.fajr, prayerTimezone),
        settings.offsets.fajr,
      ),
      PrayerTimeKind.sunrise: _withOffset(
        baseSunrise,
        settings.offsets.sunrise,
      ),
      PrayerTimeKind.dhuhr: _withOffset(
        _displayTime(baseTimes.dhuhr, prayerTimezone),
        settings.offsets.dhuhr,
      ),
      PrayerTimeKind.asr: _withOffset(
        _displayTime(baseTimes.asr, prayerTimezone),
        settings.offsets.asr,
      ),
      PrayerTimeKind.maghrib: _withOffset(
        baseMaghrib,
        settings.offsets.maghrib,
      ),
      PrayerTimeKind.isha: _withOffset(customIsha, settings.offsets.isha),
    };

    return PrayerDay(
      date: localDate,
      location: location,
      settings: settings,
      effectiveMethod: effectiveMethod,
      timezoneId: prayerTimezone?.name,
      usesLocationTimezone: prayerTimezone != null,
      entries: PrayerTimeKind.displayOrder
          .map(
            (PrayerTimeKind kind) => PrayerTimeEntry(
              kind: kind,
              time: times[kind]!,
              offsetMinutes: settings.offsets.forPrayer(kind),
            ),
          )
          .toList(growable: false),
    );
  }

  PrayerCalculationMethod effectiveMethodFor({
    required PrayerLocation location,
    required PrayerTimeSettings settings,
  }) {
    if (settings.method != PrayerCalculationMethod.auto) {
      return settings.method;
    }
    return bestMethodForLocation(location);
  }

  DateTime calendarDateForInstant({
    required DateTime instant,
    required PrayerLocation location,
    required PrayerTimeSettings settings,
  }) {
    final timezone.Location? prayerTimezone = _prayerTimezoneFor(
      location: location,
      settings: settings,
    );
    final DateTime zonedInstant = prayerTimezone == null
        ? instant.toLocal()
        : timezone.TZDateTime.from(instant.toUtc(), prayerTimezone);
    return DateTime(zonedInstant.year, zonedInstant.month, zonedInstant.day);
  }

  PrayerCalculationMethod bestMethodForLocation(PrayerLocation location) {
    final String countryCode = location.countryCode?.toUpperCase() ?? '';
    return switch (countryCode) {
      'AE' || 'OM' || 'BH' => PrayerCalculationMethod.dubai,
      'KW' => PrayerCalculationMethod.kuwait,
      'QA' => PrayerCalculationMethod.qatar,
      'SA' => PrayerCalculationMethod.ummAlQura,
      'EG' => PrayerCalculationMethod.egyptian,
      'PK' || 'IN' || 'BD' || 'AF' => PrayerCalculationMethod.karachi,
      'GB' || 'UK' || 'IE' => PrayerCalculationMethod.uk18,
      'MA' => PrayerCalculationMethod.morocco,
      'IR' => PrayerCalculationMethod.tehran,
      'US' || 'CA' => PrayerCalculationMethod.northAmerica,
      'SG' || 'MY' || 'ID' || 'BN' => PrayerCalculationMethod.singapore,
      'TR' => PrayerCalculationMethod.turkiye,
      _ => PrayerCalculationMethod.muslimWorldLeague,
    };
  }

  PrayerHighLatitudeRule effectiveHighLatitudeRuleFor({
    required PrayerLocation location,
    required PrayerTimeSettings settings,
    PrayerCalculationMethod? effectiveMethod,
  }) {
    if (settings.highLatitudeRule != PrayerHighLatitudeRule.auto) {
      return settings.highLatitudeRule;
    }
    if (!_needsHighLatitudeAdjustment(location)) {
      return PrayerHighLatitudeRule.none;
    }

    final PrayerCalculationMethod method =
        effectiveMethod ??
        effectiveMethodFor(location: location, settings: settings);
    if (method == PrayerCalculationMethod.moonsightingCommittee) {
      return PrayerHighLatitudeRule.oneSeventh;
    }
    return PrayerHighLatitudeRule.angleBased;
  }

  adhan.HighLatitudeRule resolveHighLatitudeRule({
    required PrayerLocation location,
    required PrayerTimeSettings settings,
    PrayerCalculationMethod? effectiveMethod,
  }) {
    final PrayerHighLatitudeRule appRule = effectiveHighLatitudeRuleFor(
      location: location,
      settings: settings,
      effectiveMethod: effectiveMethod,
    );
    return _adhanHighLatitudeRuleFor(appRule);
  }

  NextPrayer nextPrayer({
    required PrayerDay day,
    required DateTime now,
    PrayerDay? tomorrow,
  }) {
    final DateTime localNow = now.toLocal();
    final DateTime displayNow = _floorToMinute(localNow);
    for (final PrayerTimeKind kind in PrayerTimeKind.nextPrayerOrder) {
      final PrayerTimeEntry entry = day.entryFor(kind);
      final DateTime displayTime = _floorToMinute(entry.time);
      if (displayTime.isAfter(displayNow)) {
        return NextPrayer(
          entry: entry,
          countdown: displayTime.difference(localNow),
        );
      }
    }

    final PrayerTimeEntry fajr = (tomorrow ?? day).entryFor(
      PrayerTimeKind.fajr,
    );
    final DateTime nextFajr = tomorrow == null
        ? fajr.time.add(const Duration(days: 1))
        : fajr.time;
    final DateTime displayNextFajr = _floorToMinute(nextFajr);
    return NextPrayer(
      entry: PrayerTimeEntry(
        kind: PrayerTimeKind.fajr,
        time: nextFajr,
        offsetMinutes: fajr.offsetMinutes,
      ),
      countdown: displayNextFajr.difference(localNow),
    );
  }

  NextPrayer calculateNextPrayer({
    required DateTime now,
    required PrayerLocation location,
    required PrayerTimeSettings settings,
  }) {
    final DateTime todayDate = calendarDateForInstant(
      instant: now,
      location: location,
      settings: settings,
    );
    final PrayerDay today = calculateDay(
      date: todayDate,
      location: location,
      settings: settings,
    );
    final PrayerDay tomorrow = calculateDay(
      date: DateTime(todayDate.year, todayDate.month, todayDate.day + 1),
      location: location,
      settings: settings,
    );
    return nextPrayer(day: today, tomorrow: tomorrow, now: now);
  }

  adhan.CalculationParameters _parametersFor({
    required PrayerCalculationMethod method,
    required PrayerTimeSettings settings,
    required adhan.HighLatitudeRule highLatitudeRule,
  }) {
    final adhan.CalculationParameters parameters = switch (method) {
      PrayerCalculationMethod.auto ||
      PrayerCalculationMethod.muslimWorldLeague =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      PrayerCalculationMethod.egyptian =>
        adhan.CalculationMethodParameters.egyptian(),
      PrayerCalculationMethod.ummAlQura =>
        adhan.CalculationMethodParameters.ummAlQura(),
      PrayerCalculationMethod.dubai =>
        adhan.CalculationMethodParameters.dubai(),
      PrayerCalculationMethod.kuwait =>
        adhan.CalculationMethodParameters.kuwait(),
      PrayerCalculationMethod.qatar =>
        adhan.CalculationMethodParameters.qatar(),
      PrayerCalculationMethod.karachi =>
        adhan.CalculationMethodParameters.karachi(),
      PrayerCalculationMethod.northAmerica =>
        adhan.CalculationMethodParameters.northAmerica(),
      PrayerCalculationMethod.moonsightingCommittee =>
        adhan.CalculationMethodParameters.moonsightingCommittee(),
      PrayerCalculationMethod.morocco =>
        adhan.CalculationMethodParameters.morocco(),
      PrayerCalculationMethod.singapore =>
        adhan.CalculationMethodParameters.singapore(),
      PrayerCalculationMethod.tehran =>
        adhan.CalculationMethodParameters.tehran(),
      PrayerCalculationMethod.turkiye =>
        adhan.CalculationMethodParameters.turkiye(),
      PrayerCalculationMethod.uk18 || PrayerCalculationMethod.custom =>
        adhan.CalculationMethodParameters.other(),
    };

    parameters.madhab = switch (settings.asrMethod) {
      PrayerAsrMethod.standard => adhan.Madhab.shafi,
      PrayerAsrMethod.hanafi => adhan.Madhab.hanafi,
    };

    if (method == PrayerCalculationMethod.uk18) {
      parameters.fajrAngle = 18;
      parameters.ishaAngle = 18;
      parameters.ishaInterval = null;
      parameters.maghribAngle = null;
    } else if (method == PrayerCalculationMethod.custom) {
      parameters.fajrAngle = settings.customFajrAngle;
      parameters.ishaAngle = settings.customIshaAngle;
      parameters.ishaInterval = _customIshaIntervalForCalculation(settings);
      parameters.maghribAngle = settings.customMaghribAngle;
    }

    parameters.highLatitudeRule = highLatitudeRule;

    return parameters;
  }

  adhan.HighLatitudeRule _adhanHighLatitudeRuleFor(
    PrayerHighLatitudeRule rule,
  ) {
    return switch (rule) {
      PrayerHighLatitudeRule.auto ||
      PrayerHighLatitudeRule.none => adhan.HighLatitudeRule.middleOfTheNight,
      PrayerHighLatitudeRule.middleOfTheNight =>
        adhan.HighLatitudeRule.middleOfTheNight,
      PrayerHighLatitudeRule.oneSeventh =>
        adhan.HighLatitudeRule.seventhOfTheNight,
      PrayerHighLatitudeRule.angleBased => adhan.HighLatitudeRule.twilightAngle,
    };
  }

  bool _needsHighLatitudeAdjustment(PrayerLocation location) {
    return location.latitude.abs() >= 48;
  }

  int? _customIshaIntervalForCalculation(PrayerTimeSettings settings) {
    return switch (settings.customIshaMode) {
      PrayerCustomIshaMode.interval ||
      PrayerCustomIshaMode.latestCap => settings.customIshaInterval,
      PrayerCustomIshaMode.angle || PrayerCustomIshaMode.fixedTime => null,
    };
  }

  DateTime _customIshaTime({
    required DateTime baseIsha,
    required DateTime baseMaghrib,
    required DateTime localDate,
    required PrayerCalculationMethod method,
    required timezone.Location? prayerTimezone,
    required PrayerTimeSettings settings,
  }) {
    if (method != PrayerCalculationMethod.custom) return baseIsha;

    final DateTime isha = switch (settings.customIshaMode) {
      PrayerCustomIshaMode.angle => baseIsha,
      PrayerCustomIshaMode.interval =>
        settings.customIshaInterval == null
            ? baseIsha
            : baseMaghrib.add(Duration(minutes: settings.customIshaInterval!)),
      PrayerCustomIshaMode.fixedTime => _clockTimeOnDate(
        date: localDate,
        hour: settings.customIshaFixedTimeHour,
        minute: settings.customIshaFixedTimeMinute,
        prayerTimezone: prayerTimezone,
      ),
      PrayerCustomIshaMode.latestCap => _cappedIshaTime(
        baseIsha: baseIsha,
        cap: _clockTimeOnDate(
          date: localDate,
          hour: settings.customIshaLatestCapHour,
          minute: settings.customIshaLatestCapMinute,
          prayerTimezone: prayerTimezone,
        ),
      ),
    };

    // Custom Isha mode is resolved first; the manual Isha offset is applied
    // afterwards with the other prayer offsets.
    return isha;
  }

  DateTime _cappedIshaTime({
    required DateTime baseIsha,
    required DateTime cap,
  }) {
    return baseIsha.isAfter(cap) ? cap : baseIsha;
  }

  DateTime _clockTimeOnDate({
    required DateTime date,
    required int hour,
    required int minute,
    required timezone.Location? prayerTimezone,
  }) {
    if (prayerTimezone == null) {
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    return timezone.TZDateTime(
      prayerTimezone,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  timezone.Location? _prayerTimezoneFor({
    required PrayerLocation location,
    required PrayerTimeSettings settings,
  }) {
    if (!settings.useLocationTimezone) return null;
    return PrayerTimezoneService.locationForId(location.timezoneId);
  }

  DateTime _displayTime(DateTime time, timezone.Location? prayerTimezone) {
    final DateTime utcTime = time.isUtc ? time : time.toUtc();
    if (prayerTimezone == null) return utcTime.toLocal();
    return timezone.TZDateTime.from(utcTime, prayerTimezone);
  }

  DateTime _withOffset(DateTime time, int minutes) {
    if (minutes == 0) return time;
    return time.add(Duration(minutes: minutes));
  }

  DateTime _floorToMinute(DateTime time) {
    if (time is timezone.TZDateTime) {
      return timezone.TZDateTime(
        time.location,
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute,
      );
    }
    return DateTime(time.year, time.month, time.day, time.hour, time.minute);
  }
}
