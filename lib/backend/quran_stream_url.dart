import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/utils/library.dart' show AppReciter;

class QuranAudioService {
  String getSurahUrl(int surah) {
    final savedCode = SettingsDB().get('reciter', defaultValue: "ar.alafasi");
    final reciter = AppReciter.fromCode(savedCode);

    return reciter.surahUrl(surah);
  }
  String getAyahUrl(int surah, int ayah) {
    final savedCode = SettingsDB().get("reciter", defaultValue: "ar.alafasi");
    final reciter = AppReciter.fromCode(savedCode);

    return reciter.ayahUrl(surah, ayah);
  }
}