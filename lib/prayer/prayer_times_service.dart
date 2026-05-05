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
    final adhan.CalculationParameters parameters = _parametersFor(
      effectiveMethod,
      settings,
      
    );
    final DateTime localDate = prayerTimezone == null
        ? DateTime(date.year, date.month, date.day)
        : timezone.TZDateTime(
            prayerTimezone,
            date.year,
            date.month,
            date.day,
          );
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
        _displayTime(baseTimes.maghrib, prayerTimezone),
        settings.offsets.maghrib,
      ),
      PrayerTimeKind.isha: _withOffset(
        _displayTime(baseTimes.isha, prayerTimezone),
        settings.offsets.isha,
      ),
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
      'US' || 'CA' => PrayerCalculationMethod.northAmerica,
      'SG' || 'MY' || 'ID' || 'BN' => PrayerCalculationMethod.singapore,
      'TR' => PrayerCalculationMethod.turkiye,
      _ => PrayerCalculationMethod.muslimWorldLeague,
    };
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

  adhan.CalculationParameters _parametersFor(
    PrayerCalculationMethod method,
    PrayerTimeSettings settings,
  ) {
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
      PrayerCalculationMethod.singapore =>
        adhan.CalculationMethodParameters.singapore(),
      PrayerCalculationMethod.turkiye =>
        adhan.CalculationMethodParameters.turkiye(),
      PrayerCalculationMethod.custom =>
        adhan.CalculationMethodParameters.other(),
    };

    parameters.madhab = switch (settings.asrMethod) {
      PrayerAsrMethod.standard => adhan.Madhab.shafi,
      PrayerAsrMethod.hanafi => adhan.Madhab.hanafi,
    };

    if (method == PrayerCalculationMethod.custom) {
      parameters.fajrAngle = settings.customFajrAngle;
      parameters.ishaAngle = settings.customIshaAngle;
      parameters.ishaInterval = settings.customIshaInterval;
      parameters.maghribAngle = settings.customMaghribAngle;
    }

    parameters.highLatitudeRule = adhan.HighLatitudeRule.seventhOfTheNight;

    return parameters;
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
