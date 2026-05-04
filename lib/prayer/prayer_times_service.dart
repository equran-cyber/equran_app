import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:equran/prayer/prayer_models.dart';

class PrayerTimesService {
  const PrayerTimesService();

  PrayerDay calculateDay({
    required DateTime date,
    required PrayerLocation location,
    required PrayerTimeSettings settings,
  }) {
    final PrayerCalculationMethod effectiveMethod = effectiveMethodFor(
      location: location,
      settings: settings,
    );
    final adhan.CalculationParameters parameters = _parametersFor(
      effectiveMethod,
      settings,
    );
    // Changge date var to something to test functionality
    // date = DateTime(2030, 4, 17);
    final DateTime localDate = DateTime(date.year, date.month, date.day);
    final adhan.PrayerTimes baseTimes = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(location.latitude, location.longitude),
      date: localDate,
      calculationParameters: parameters,
      precision: true,
    );
    final DateTime baseSunrise = _local(baseTimes.sunrise);

    final Map<PrayerTimeKind, DateTime> times = <PrayerTimeKind, DateTime>{
      PrayerTimeKind.fajr: _withOffset(
        _local(baseTimes.fajr),
        settings.offsets.fajr,
      ),
      PrayerTimeKind.sunrise: _withOffset(
        baseSunrise,
        settings.offsets.sunrise,
      ),
      PrayerTimeKind.dhuhr: _withOffset(
        _local(baseTimes.dhuhr),
        settings.offsets.dhuhr,
      ),
      PrayerTimeKind.asr: _withOffset(
        _local(baseTimes.asr),
        settings.offsets.asr,
      ),
      PrayerTimeKind.maghrib: _withOffset(
        _local(baseTimes.maghrib),
        settings.offsets.maghrib,
      ),
      PrayerTimeKind.isha: _withOffset(
        _local(baseTimes.isha),
        settings.offsets.isha,
      ),
    };

    return PrayerDay(
      date: localDate,
      location: location,
      settings: settings,
      effectiveMethod: effectiveMethod,
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
    final PrayerDay today = calculateDay(
      date: now,
      location: location,
      settings: settings,
    );
    final PrayerDay tomorrow = calculateDay(
      date: now.add(const Duration(days: 1)),
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

    return parameters;
  }

  DateTime _local(DateTime time) {
    return time.isUtc ? time.toLocal() : time;
  }

  DateTime _withOffset(DateTime time, int minutes) {
    if (minutes == 0) return time;
    return time.add(Duration(minutes: minutes));
  }

  DateTime _floorToMinute(DateTime time) {
    return DateTime(time.year, time.month, time.day, time.hour, time.minute);
  }
}
