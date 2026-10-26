import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String _getCacheKey(String text, String toLang) {
    // Simple but collision-resistant hash using hashCode combination
    final combined = '${toLang}_$text';
    final hash = combined.hashCode.abs();
    return 'trans_${toLang}_$hash';
  }

  static Future<String> translateAndCache(String text, {String from = 'ar', String to = 'ckb'}) async {
    if (text.trim().isEmpty) return '';
    
    final targetLang = to == 'ku' ? 'ckb' : to;
    final cacheKey = _getCacheKey(text, targetLang);

    if (_prefs == null) {
      await init();
    }

    // 1. Check cache
    final cached = _prefs?.getString(cacheKey);
    if (cached != null) {
      return cached;
    }

    // 2. Fetch Translation
    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$from&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data[0] != null) {
          final translated = (data[0] as List<dynamic>)
              .map((item) => item != null && item[0] != null ? item[0].toString() : '')
              .join('');
          
          if (translated.trim().isNotEmpty) {
            await _prefs?.setString(cacheKey, translated);
            return translated;
          }
        }
      }
    } catch (e) {
      // Return empty/fallback silently
    }
    return '';
  }
}
