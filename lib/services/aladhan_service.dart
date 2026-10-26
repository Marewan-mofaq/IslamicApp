import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/awqaf_kurdistan_data.dart';
import 'data_service.dart';
import 'prayer_service.dart';

class AladhanService {
  /// City Kurdish name / alias mapping to cityId for official Kurdistan schedules
  static const Map<String, String> _ba8CityAliasToId = {
    'هەولێر': 'erbil',
    'سلێمانی': 'sulaymaniyah',
    'دهۆک': 'duhok',
    'کەرکوک': 'kirkuk',
    'کەرکووک': 'kirkuk',
    'هەلەبجە': 'halabja',
    'هەڵەبجە': 'halabja',
    'کەلار': 'kalar',
    'چەمچەماڵ': 'chamchamal',
    'ئاکرێ': 'akre',
    'دەربەندیخان': 'darbandikhan',
    'زاخۆ': 'zakho',
    'ڕانیە': 'rania',
    'قەڵادزێ': 'qaladiza',
    'کۆیە': 'koya',
    'کفری': 'kifri',
    'بەردەڕەش': 'bardarash',
    'موصل': 'mosul',
    'مووسڵ': 'mosul',
  };

  /// Synchronous retrieval of cached official times if already saved for today
  static Map<String, String>? getCachedTimes({
    required String cityId,
    required Map<String, int> offsets,
    required SharedPreferences? prefs,
    String? countryCode,
  }) {
    final cId = cityId.toLowerCase();
    final isKurdistan = (countryCode?.toUpperCase() == 'IQ') ||
        PrayerService.cityIdToAwqafKey.containsKey(cId) ||
        AwqafKurdistanData.data.containsKey(cId);

    // 1. Direct official Awqaf database lookup (for Kurdistan & Iraq only)
    if (isKurdistan) {
      final awqafTimes = PrayerService.getOfficialAwqafTimes(
        cityId: cityId,
        offsets: offsets,
      );
      if (awqafTimes != null) {
        return awqafTimes;
      }
    }

    if (prefs == null) return null;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final cacheKey = 'prayer_official_v6_${cityId.toLowerCase()}_$dateStr';
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cached);
        return _applyOffsets(decoded.cast<String, String>(), offsets);
      } catch (_) {}
    }
    return null;
  }

  /// Main entry point to get prayer times for the given city and parameters
  static Future<Map<String, String>> fetchTimes({
    required double latitude,
    required double longitude,
    required String method,
    required String asrMadhab,
    required Map<String, int> offsets,
    required String cityId,
    String? countryCode,
  }) async {
    final cId = cityId.toLowerCase();
    final isKurdistan = (countryCode?.toUpperCase() == 'IQ') ||
        PrayerService.cityIdToAwqafKey.containsKey(cId) ||
        AwqafKurdistanData.data.containsKey(cId);

    // 1. Prioritize official Kurdistan Ministry of Awqaf database for Kurdistan & Iraq
    if (isKurdistan) {
      if (DataService.awqafDatabase == null) {
        await DataService.loadAwqafPrayerDatabase();
      }
      final awqafTimes = PrayerService.getOfficialAwqafTimes(
        cityId: cityId,
        offsets: offsets,
      );
      if (awqafTimes != null) {
        return awqafTimes;
      }
    }

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final cacheKey = 'prayer_official_v6_${cityId.toLowerCase()}_$dateStr';

    final prefs = await SharedPreferences.getInstance();
    _cleanupOldCache(prefs, dateStr);

    // 1. Try reading from local cache first
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cached);
        return _applyOffsets(decoded.cast<String, String>(), offsets);
      } catch (_) {}
    }

    // 2. For Kurdistan cities: fetch official Ministry of Endowments table from ba8.org
    if (isKurdistan) {
      final ba8Result = await _fetchFromBa8(cId, dateStr, prefs);
      if (ba8Result != null) {
        return _applyOffsets(ba8Result, offsets);
      }
    }

    // 3. For worldwide cities: fetch official timings from Aladhan API
    final aladhanResult = await _fetchFromAladhanAPI(
      latitude,
      longitude,
      method,
      asrMadhab,
      dateStr,
      countryCode: countryCode,
    );
    if (aladhanResult != null) {
      await prefs.setString(cacheKey, jsonEncode(aladhanResult));
      return _applyOffsets(aladhanResult, offsets);
    }

    // 4. Fallback: dynamic local astronomical calculation for today's date
    return PrayerService.calculateTimes(
      latitude: latitude,
      longitude: longitude,
      method: method,
      asrMadhab: asrMadhab,
      offsets: offsets,
      cityId: cityId,
      countryCode: countryCode,
    );
  }

  /// Fetches live official Kurdistan mosque timings from ba8.org/KatiBang
  static Future<Map<String, String>?> _fetchFromBa8(
    String targetCityId,
    String dateStr,
    SharedPreferences prefs,
  ) async {
    try {
      final fullCacheKey = 'ba8_full_table_$dateStr';
      final cachedFull = prefs.getString(fullCacheKey);
      if (cachedFull != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedFull);
        if (decoded.containsKey(targetCityId)) {
          final cityMap = (decoded[targetCityId] as Map<String, dynamic>).cast<String, String>();
          return cityMap;
        }
      }

      final res = await http
          .get(Uri.parse('https://ba8.org/KatiBang'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final html = res.body;
        final rowRegex = RegExp(
          r'<tr>\s*<td class="location"\s*>(.*?)</td>\s*<td align="center"><b>(.*?)</b></td>\s*<td align="center"><b>(.*?)</b></td>\s*<td align="center"><b>(.*?)</b></td>\s*<td align="center"><b>(.*?)</b></td>\s*<td align="center"><b>(.*?)</b></td>\s*<td align="center"><b>(.*?)</b></td>',
          dotAll: true,
        );

        final Map<String, Map<String, String>> fullTable = {};

        for (final m in rowRegex.allMatches(html)) {
          final name = m.group(1)?.trim() ?? '';
          final cId = _ba8CityAliasToId[name];
          if (cId != null) {
            fullTable[cId] = {
              'Fajr': _formatTime24(m.group(2) ?? '', false),
              'Sunrise': _formatTime24(m.group(3) ?? '', false),
              'Dhuhr': _formatTime24(m.group(4) ?? '', false),
              'Asr': _formatTime24(m.group(5) ?? '', true),
              'Maghrib': _formatTime24(m.group(6) ?? '', true),
              'Isha': _formatTime24(m.group(7) ?? '', true),
            };
          }
        }

        if (fullTable.isNotEmpty) {
          await prefs.setString(fullCacheKey, jsonEncode(fullTable));

          for (final entry in fullTable.entries) {
            await prefs.setString('prayer_official_v5_${entry.key}_$dateStr', jsonEncode(entry.value));
          }

          if (fullTable.containsKey(targetCityId)) {
            return fullTable[targetCityId];
          }
          if (targetCityId == 'soran' && fullTable.containsKey('erbil')) {
            return fullTable['erbil'];
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String _normalizeDigits(String input) {
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(eastern[i], western[i]).replaceAll(persian[i], western[i]);
    }
    return res;
  }

  static String _formatTime24(String rawTime, bool isAfternoon) {
    final clean = _normalizeDigits(rawTime).trim();
    final parts = clean.split(':');
    if (parts.length != 2) return clean;
    int h = int.tryParse(parts[0]) ?? 0;
    final int m = int.tryParse(parts[1]) ?? 0;
    if (isAfternoon && h < 12) {
      h += 12;
    }
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static int getMethodIdForCountry({String? countryCode, String? method}) {
    final code = (countryCode ?? '').toUpperCase();
    if (code == 'SA' || code == 'YE' || code == 'OM') return 4; // Umm Al-Qura (Makkah)
    if (code == 'AE') return 16; // Dubai
    if (code == 'KW') return 9; // Kuwait
    if (code == 'QA') return 10; // Qatar
    if (code == 'TR') return 13; // Diyanet (Turkey)
    if (code == 'EG' || code == 'JO' || code == 'PS' || code == 'SY' || code == 'LB' || code == 'SD' || code == 'LY') {
      return 5; // Egyptian General Authority
    }
    if (code == 'MA') return 21; // Morocco
    if (code == 'DZ') return 19; // Algeria
    if (code == 'TN') return 18; // Tunisia
    if (code == 'MY') return 17; // JAKIM (Malaysia)
    if (code == 'ID') return 20; // KEMENAG (Indonesia)
    if (code == 'SG') return 11; // MUIS (Singapore)
    if (code == 'FR') return 12; // UOIF (France)
    if (code == 'RU') return 14; // Russia
    if (code == 'US' || code == 'CA' || code == 'MX') return 2; // ISNA (North America)
    if (code == 'PK' || code == 'IN' || code == 'BD' || code == 'AF') return 1; // Karachi
    if (code == 'IR') return 7; // University of Tehran
    if (code == 'IQ') return 13; // Iraq/Kurdistan (Awqaf / Diyanet aligned)

    // Europe and major world countries standard: Muslim World League
    const europeAndWorldCodes = {
      'GB', 'DE', 'NL', 'BE', 'SE', 'NO', 'DK', 'FI', 'CH', 'AT', 'IT', 'ES', 'GR', 'PL', 'RO', 'CZ', 'HU', 'IE', 'PT',
      'UA', 'AU', 'NZ', 'JP', 'KR', 'CN', 'BR', 'AR', 'CL', 'CO', 'ZA', 'NG', 'KE'
    };
    if (europeAndWorldCodes.contains(code)) {
      return 3; // Muslim World League
    }

    // Explicit user settings override
    if (method == 'UmmAlQura') return 4;
    if (method == 'Egyptian') return 5;
    if (method == 'Karachi') return 1;
    if (method == 'ISNA') return 2;
    if (method == 'Diyanet') return 13;
    if (method == 'Tehran') return 7;
    return 3; // Muslim World League (default for Europe and rest of world)
  }

  /// Fetches from Aladhan API (api.aladhan.com) as primary live source for worldwide cities
  static Future<Map<String, String>?> _fetchFromAladhanAPI(
    double latitude,
    double longitude,
    String method,
    String asrMadhab,
    String dateStr, {
    String? countryCode,
  }) async {
    try {
      final methodId = getMethodIdForCountry(countryCode: countryCode, method: method);
      final school = asrMadhab == 'Hanafi' ? 1 : 0;

      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings/$dateStr'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&method=$methodId'
        '&school=$school',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (compatible; IslamicApp/1.0)',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 200) {
          final timings = data['data']['timings'] as Map<String, dynamic>;
          return {
            'Fajr': _formatTime(timings['Fajr']),
            'Sunrise': _formatTime(timings['Sunrise']),
            'Dhuhr': _formatTime(timings['Dhuhr']),
            'Asr': _formatTime(timings['Asr']),
            'Maghrib': _formatTime(timings['Maghrib']),
            'Isha': _formatTime(timings['Isha']),
          };
        }
      }
    } catch (_) {}
    return null;
  }

  static String _formatTime(dynamic raw) {
    if (raw == null) return '--:--';
    final str = raw.toString().trim();
    final parts = str.split(' ');
    final timeStr = parts.isNotEmpty ? parts[0] : str;
    final tParts = timeStr.split(':');
    if (tParts.length >= 2) {
      final h = tParts[0].padLeft(2, '0');
      final m = tParts[1].padLeft(2, '0');
      return '$h:$m';
    }
    return timeStr;
  }

  static Map<String, String> _applyOffsets(
    Map<String, String> baseTimes,
    Map<String, int> offsets,
  ) {
    final Map<String, String> adjusted = {};
    baseTimes.forEach((key, val) {
      final offsetMins = offsets[key] ?? 0;
      if (offsetMins == 0 || val == '--:--') {
        adjusted[key] = val;
      } else {
        final parts = val.split(':');
        if (parts.length == 2) {
          int h = int.tryParse(parts[0]) ?? 0;
          int m = int.tryParse(parts[1]) ?? 0;
          final totalMins = (h * 60 + m + offsetMins + 1440) % 1440;
          final newH = (totalMins ~/ 60).toString().padLeft(2, '0');
          final newM = (totalMins % 60).toString().padLeft(2, '0');
          adjusted[key] = '$newH:$newM';
        } else {
          adjusted[key] = val;
        }
      }
    });
    return adjusted;
  }

  static void _cleanupOldCache(SharedPreferences prefs, String currentDateStr) {
    try {
      final keys = prefs.getKeys();
      for (final k in keys) {
        if ((k.startsWith('prayer_official_v5_') || k.startsWith('ba8_full_table_')) &&
            !k.endsWith(currentDateStr)) {
          prefs.remove(k);
        }
      }
    } catch (_) {}
  }
}
