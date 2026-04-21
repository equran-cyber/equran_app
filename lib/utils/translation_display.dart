import 'package:quran/quran.dart' as quran;

String translationDisplayName(quran.Translation translation) {
  return switch (translation) {
    quran.Translation.enSaheeh => 'English (Saheeh)',
    quran.Translation.enClearQuran => 'English (Clear Quran)',
    quran.Translation.trSaheeh => 'Turkish (Saheeh)',
    quran.Translation.mlAbdulHameed => 'Malayalam (Abdul Hameed)',
    quran.Translation.faHusseinDari => 'Persian (Hussein Dari)',
    quran.Translation.frHamidullah => 'French (Hamidullah)',
    quran.Translation.itPiccardo => 'Italian (Piccardo)',
    quran.Translation.nlSiregar => 'Dutch (Siregar)',
    quran.Translation.portuguese => 'Portuguese',
    quran.Translation.ruKuliev => 'Russian (Kuliev)',
    quran.Translation.urdu => 'Urdu',
    quran.Translation.bengali => 'Bengali',
    quran.Translation.chinese => 'Chinese',
    quran.Translation.indonesian => 'Indonesian',
    quran.Translation.spanish => 'Spanish',
    quran.Translation.swedish => 'Swedish',
  };
}
