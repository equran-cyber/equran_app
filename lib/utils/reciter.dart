enum AppReciter {
  misharyRashidAlAfasy(code: '1', englishName: 'Mishary Rashid Al Afasy'),
  abuBakrAlShatri(code: '2', englishName: 'Abu Bakr Al Shatri'),
  nasserAlQatami(code: '3', englishName: 'Nasser Al Qatami'),
  yasserAlDosari(code: '4', englishName: 'Yasser Al Dosari'),
  haniArRifai(code: '5', englishName: 'Hani Ar Rifai');

  final String code;
  final String englishName;

  const AppReciter({required this.code, required this.englishName});

  static const Map<String, String> _legacyCodeMap = <String, String>{
    'ar.alafasy': '1',
    'ar.alafasi': '1',
  };

  static String normalizeCode(String? code) {
    if (code == null || code.isEmpty) {
      return AppReciter.misharyRashidAlAfasy.code;
    }
    return _legacyCodeMap[code] ?? code;
  }

  static AppReciter fromCode(String? code) {
    final String normalizedCode = normalizeCode(code);
    return AppReciter.values.firstWhere(
      (r) => r.code == normalizedCode,
      orElse: () => AppReciter.misharyRashidAlAfasy,
    );
  }
}
