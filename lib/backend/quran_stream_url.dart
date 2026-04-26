import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/utils/library.dart' show AppReciter;
import 'package:http/http.dart' as http;
import 'dart:convert';

class QuranAudioService {
  static const String _baseUrl = 'https://quranapi.pages.dev/api';
  static final Map<String, Future<Map<String, dynamic>>> _responseCache =
      <String, Future<Map<String, dynamic>>>{};

  AppReciter get selectedReciter {
    final String savedCode = SettingsDB().get('reciter', defaultValue: '1');
    final String normalizedCode = AppReciter.normalizeCode(savedCode);
    if (normalizedCode != savedCode) {
      SettingsDB().put('reciter', normalizedCode);
    }
    return AppReciter.fromCode(normalizedCode);
  }

  Future<String> getSurahUrl(int surah) async {
    final reciter = selectedReciter;
    final Map<String, dynamic> response = await _getJson(
      '$_baseUrl/$surah.json',
    );
    return _extractAudioUrl(response, reciter);
  }

  Future<String> getAyahUrl(int surah, int ayah) async {
    final reciter = selectedReciter;
    final Map<String, dynamic> response = await _getJson(
      '$_baseUrl/$surah/$ayah.json',
    );
    return _extractAudioUrl(response, reciter);
  }

  Future<Map<String, dynamic>> _getJson(String url) {
    return _responseCache.putIfAbsent(url, () async {
      try {
        final http.Response response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Audio API request failed: ${response.statusCode}');
        }

        final Object? decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('Unexpected audio API response format.');
        }
        return decoded;
      } catch (_) {
        _responseCache.remove(url);
        rethrow;
      }
    });
  }

  String _extractAudioUrl(Map<String, dynamic> response, AppReciter reciter) {
    final dynamic audio = response['audio'];
    if (audio is! Map) {
      throw Exception('Audio data missing from API response.');
    }

    final dynamic reciterEntry = audio[reciter.code];
    if (reciterEntry is! Map) {
      throw Exception('Selected reciter is unavailable for this item.');
    }

    final dynamic originalUrl = reciterEntry['originalUrl'];
    if (originalUrl is String && originalUrl.isNotEmpty) {
      return originalUrl;
    }

    final dynamic fallbackUrl = reciterEntry['url'];
    if (fallbackUrl is String && fallbackUrl.isNotEmpty) {
      return fallbackUrl;
    }

    throw Exception('No audio URL available for the selected reciter.');
  }
}
