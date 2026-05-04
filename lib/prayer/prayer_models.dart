enum PrayerTimeKind {
  fajr('fajr', 'Fajr'),
  sunrise('sunrise', 'Sunrise'),
  dhuhr('dhuhr', 'Dhuhr'),
  asr('asr', 'Asr'),
  maghrib('maghrib', 'Maghrib'),
  isha('isha', 'Isha');

  const PrayerTimeKind(this.id, this.label);

  final String id;
  final String label;

  static const List<PrayerTimeKind> displayOrder = <PrayerTimeKind>[
    fajr,
    sunrise,
    dhuhr,
    asr,
    maghrib,
    isha,
  ];

  static const List<PrayerTimeKind> nextPrayerOrder = <PrayerTimeKind>[
    fajr,
    dhuhr,
    asr,
    maghrib,
    isha,
  ];

  static PrayerTimeKind fromId(String? id) {
    return PrayerTimeKind.values.firstWhere(
      (PrayerTimeKind kind) => kind.id == id,
      orElse: () => PrayerTimeKind.fajr,
    );
  }
}

enum PrayerCalculationMethod {
  auto('auto', 'Best for location'),
  muslimWorldLeague('muslimWorldLeague', 'Muslim World League'),
  egyptian('egyptian', 'Egyptian'),
  ummAlQura('ummAlQura', 'Umm al-Qura'),
  dubai('dubai', 'Dubai / Gulf'),
  kuwait('kuwait', 'Kuwait'),
  qatar('qatar', 'Qatar'),
  karachi('karachi', 'Karachi'),
  northAmerica('northAmerica', 'ISNA'),
  singapore('singapore', 'Singapore'),
  turkiye('turkiye', 'Turkey / Diyanet'),
  custom('custom', 'Custom');

  const PrayerCalculationMethod(this.id, this.label);

  final String id;
  final String label;

  static PrayerCalculationMethod fromId(String? id) {
    return PrayerCalculationMethod.values.firstWhere(
      (PrayerCalculationMethod method) => method.id == id,
      orElse: () => PrayerCalculationMethod.auto,
    );
  }

  String get shortLabel {
    return switch (this) {
      PrayerCalculationMethod.auto => 'Auto',
      PrayerCalculationMethod.muslimWorldLeague => 'MWL',
      PrayerCalculationMethod.egyptian => 'Egyptian',
      PrayerCalculationMethod.ummAlQura => 'Umm al-Qura',
      PrayerCalculationMethod.dubai => 'Dubai',
      PrayerCalculationMethod.kuwait => 'Kuwait',
      PrayerCalculationMethod.qatar => 'Qatar',
      PrayerCalculationMethod.karachi => 'Karachi',
      PrayerCalculationMethod.northAmerica => 'ISNA',
      PrayerCalculationMethod.singapore => 'Singapore',
      PrayerCalculationMethod.turkiye => 'Turkey',
      PrayerCalculationMethod.custom => 'Custom',
    };
  }
}

enum PrayerAsrMethod {
  standard('standard', 'Standard'),
  hanafi('hanafi', 'Hanafi');

  const PrayerAsrMethod(this.id, this.label);

  final String id;
  final String label;

  static PrayerAsrMethod fromId(String? id) {
    return PrayerAsrMethod.values.firstWhere(
      (PrayerAsrMethod method) => method.id == id,
      orElse: () => PrayerAsrMethod.standard,
    );
  }
}

enum PrayerLocationMode {
  currentDevice('currentDevice', 'Current device location'),
  manual('manual', 'Manual location');

  const PrayerLocationMode(this.id, this.label);

  final String id;
  final String label;

  static PrayerLocationMode fromId(String? id) {
    return PrayerLocationMode.values.firstWhere(
      (PrayerLocationMode mode) => mode.id == id,
      orElse: () => PrayerLocationMode.manual,
    );
  }
}

class PrayerLocation {
  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.mode,
    this.countryCode,
  });

  static PrayerLocation? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final double? latitude = _readDouble(json['latitude']);
    final double? longitude = _readDouble(json['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }
    final dynamic labelValue = json['label'];
    final dynamic countryCodeValue = json['countryCode'];
    final String? countryCode =
        countryCodeValue is String && countryCodeValue.trim().isNotEmpty
        ? countryCodeValue.trim().toUpperCase()
        : null;
    final String label = labelValue is String && labelValue.trim().isNotEmpty
        ? labelValue.trim()
        : 'Selected location';

    return PrayerLocation(
      latitude: latitude.clamp(-90, 90).toDouble(),
      longitude: longitude.clamp(-180, 180).toDouble(),
      label: label,
      countryCode: countryCode,
      mode: PrayerLocationMode.fromId(json['mode'] as String?),
    );
  }

  final double latitude;
  final double longitude;
  final String label;
  final String? countryCode;
  final PrayerLocationMode mode;

  String get displayLabel {
    final String trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty ||
        trimmedLabel == 'Current location' ||
        _looksLikeCoordinateLabel(trimmedLabel)) {
      return mode.label;
    }
    return trimmedLabel;
  }

  String get coordinateLabel {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
      'countryCode': countryCode,
      'mode': mode.id,
    };
  }
}

String prayerMethodDisplayLabel({
  required PrayerTimeSettings settings,
  required PrayerCalculationMethod effectiveMethod,
}) {
  return switch (settings.method) {
    PrayerCalculationMethod.custom => 'Custom',
    _ => effectiveMethod.shortLabel,
  };
}

class PrayerOffsets {
  const PrayerOffsets({
    this.fajr = 0,
    this.sunrise = 0,
    this.dhuhr = 0,
    this.asr = 0,
    this.maghrib = 0,
    this.isha = 0,
  });

  factory PrayerOffsets.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const PrayerOffsets();
    return PrayerOffsets(
      fajr: _readInt(json['fajr']),
      sunrise: _readInt(json['sunrise']),
      dhuhr: _readInt(json['dhuhr']),
      asr: _readInt(json['asr']),
      maghrib: _readInt(json['maghrib']),
      isha: _readInt(json['isha']),
    );
  }

  final int fajr;
  final int sunrise;
  final int dhuhr;
  final int asr;
  final int maghrib;
  final int isha;

  int forPrayer(PrayerTimeKind prayer) {
    return switch (prayer) {
      PrayerTimeKind.fajr => fajr,
      PrayerTimeKind.sunrise => sunrise,
      PrayerTimeKind.dhuhr => dhuhr,
      PrayerTimeKind.asr => asr,
      PrayerTimeKind.maghrib => maghrib,
      PrayerTimeKind.isha => isha,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fajr': fajr,
      'sunrise': sunrise,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
    };
  }
}

class PrayerTimeSettings {
  const PrayerTimeSettings({
    this.method = PrayerCalculationMethod.auto,
    this.customFajrAngle = 18,
    this.customIshaAngle = 17,
    this.customIshaInterval,
    this.customMaghribAngle,
    this.asrMethod = PrayerAsrMethod.standard,
    this.offsets = const PrayerOffsets(),
    this.use24HourFormat = false,
  });

  factory PrayerTimeSettings.defaults() {
    return const PrayerTimeSettings();
  }

  factory PrayerTimeSettings.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return PrayerTimeSettings.defaults();
    return PrayerTimeSettings(
      method: PrayerCalculationMethod.fromId(json['method'] as String?),
      customFajrAngle: _readDouble(json['customFajrAngle']) ?? 18,
      customIshaAngle: _readDouble(json['customIshaAngle']) ?? 17,
      customIshaInterval: _readNullableInt(json['customIshaInterval']),
      customMaghribAngle: _readDouble(json['customMaghribAngle']),
      asrMethod: PrayerAsrMethod.fromId(json['asrMethod'] as String?),
      offsets: PrayerOffsets.fromJson(json['offsets'] as Map?),
      use24HourFormat: json['use24HourFormat'] == true,
    );
  }

  final PrayerCalculationMethod method;
  final double customFajrAngle;
  final double customIshaAngle;
  final int? customIshaInterval;
  final double? customMaghribAngle;
  final PrayerAsrMethod asrMethod;
  final PrayerOffsets offsets;
  final bool use24HourFormat;

  PrayerTimeSettings copyWith({
    PrayerCalculationMethod? method,
    double? customFajrAngle,
    double? customIshaAngle,
    int? customIshaInterval,
    double? customMaghribAngle,
    PrayerAsrMethod? asrMethod,
    PrayerOffsets? offsets,
    bool? use24HourFormat,
  }) {
    return PrayerTimeSettings(
      method: method ?? this.method,
      customFajrAngle: customFajrAngle ?? this.customFajrAngle,
      customIshaAngle: customIshaAngle ?? this.customIshaAngle,
      customIshaInterval: customIshaInterval ?? this.customIshaInterval,
      customMaghribAngle: customMaghribAngle ?? this.customMaghribAngle,
      asrMethod: asrMethod ?? this.asrMethod,
      offsets: offsets ?? this.offsets,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'method': method.id,
      'customFajrAngle': customFajrAngle,
      'customIshaAngle': customIshaAngle,
      'customIshaInterval': customIshaInterval,
      'customMaghribAngle': customMaghribAngle,
      'asrMethod': asrMethod.id,
      'offsets': offsets.toJson(),
      'use24HourFormat': use24HourFormat,
    };
  }
}

class PrayerTimeEntry {
  const PrayerTimeEntry({
    required this.kind,
    required this.time,
    required this.offsetMinutes,
  });

  final PrayerTimeKind kind;
  final DateTime time;
  final int offsetMinutes;
}

class PrayerDay {
  const PrayerDay({
    required this.date,
    required this.location,
    required this.settings,
    required this.effectiveMethod,
    required this.entries,
  });

  final DateTime date;
  final PrayerLocation location;
  final PrayerTimeSettings settings;
  final PrayerCalculationMethod effectiveMethod;
  final List<PrayerTimeEntry> entries;

  PrayerTimeEntry entryFor(PrayerTimeKind kind) {
    return entries.firstWhere((PrayerTimeEntry entry) => entry.kind == kind);
  }
}

class NextPrayer {
  const NextPrayer({required this.entry, required this.countdown});

  final PrayerTimeEntry entry;
  final Duration countdown;
}

int _readInt(dynamic value, {int defaultValue = 0}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int? _readNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _looksLikeCoordinateLabel(String value) {
  return RegExp(
    r'^\s*-?\d{1,2}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?\s*$',
  ).hasMatch(value);
}
