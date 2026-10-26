import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../data/awqaf_kurdistan_data.dart';
import 'data_service.dart';

class PrayerService {
  /// City mapping from cityId (lowercase) to the key in assets/data/prayer_times.json
  static const Map<String, String> cityIdToAwqafKey = {
    // Kurdistan Region
    'erbil': 'hawler',
    'hawler': 'hawler',
    'sulaymaniyah': 'slemani',
    'slemani': 'slemani',
    'duhok': 'duhok',
    'kirkuk': 'kirkuk',
    'halabja': 'halabja',
    'zakho': 'zakho',
    'akre': 'akre',
    'rania': 'ranya(kon)',
    'ranya': 'ranya(kon)',
    'qaladiza': 'qaladze',
    'qaladze': 'qaladze',
    'kalar': 'kalar',
    'kifri': 'kifri',
    'soran': 'soran',
    'darbandikhan': 'darbandikhan',
    'koya': 'koya',
    'chamchamal': 'chamchamal',
    'bardarash': 'bardarash',
    'dukan': 'dukan',
    'saidsadq': 'saidsadq',
    'saidsadiq': 'saidsadq',
    'khurmal': 'khurmal',
    'taqtaq': 'taqtaq',
    'daquq': 'daquq',
    'hawija': 'hawija',
    'makhmur': 'makhmur',
    'sinjar': 'sinjar',
    'shekhan': 'shekhan',
    'khanaqin': 'khanaqin',
    'qasrok': 'qasrok',
    'bawanur': 'bawanur',
    'sarqala': 'sarqala',
    'qasre': 'qasre',
    'gokhlan': 'gokhlan',
    'qara hanjir': 'qara hanjir',
    'qadir karam': 'qadir karam',

    // Other Iraq Cities
    'baghdad': 'baghdad',
    'mosul': 'mosul',
    'basra': 'basrah',
    'basrah': 'basrah',
    'najaf': 'najaf',
    'karbala': 'karbala',
    'nasiriyah': 'nasiriyah',
    'amara': 'amarah',
    'amarah': 'amarah',
    'diwaniyah': 'diwaniyah',
    'samawah': 'samawah',
    'hillah': 'hillah',
    'ramadi': 'ramadi',
    'fallujah': 'al fallujah',
    'tikrit': 'tikrit',
    'baqubah': 'baqubah',
    'kut': 'kut',
    'samarra': "samarra'",

  };

  /// Returns official Kurdistan Ministry of Awqaf times from the compiled database
  static Map<String, String>? getOfficialAwqafTimes({
    required String cityId,
    DateTime? targetDate,
    Map<String, int> offsets = const {},
  }) {
    final cId = cityId.toLowerCase();
    // Only query Awqaf database for verified Kurdistan & Iraq cities
    if (!cityIdToAwqafKey.containsKey(cId) && !AwqafKurdistanData.data.containsKey(cId)) {
      return null;
    }
    final awqafKey = cityIdToAwqafKey[cId]?.toLowerCase() ?? cId;
    final date = targetDate ?? DateTime.now();
    final dateKey = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // 1. Primary compiled Kurdistan in-memory data (instant 0ms, 100% offline, guaranteed)
    final kurdistanCity = AwqafKurdistanData.data[awqafKey];
    if (kurdistanCity != null) {
      final line = kurdistanCity[dateKey];
      if (line != null) {
        final p = line.split(',');
        if (p.length == 6) {
          final rawTimes = {
            'Fajr': p[0],
            'Sunrise': p[1],
            'Dhuhr': p[2],
            'Asr': p[3],
            'Maghrib': p[4],
            'Isha': p[5],
          };
          return applyUserOffsets(rawTimes, offsets);
        }
      }
    }

    // 2. Secondary fallback to loaded JSON database for other 129 cities
    final db = DataService.awqafDatabase;
    if (db != null) {
      final cityMap = db[awqafKey];
      if (cityMap != null) {
        final rawTimes = cityMap[dateKey];
        if (rawTimes != null) {
          return applyUserOffsets(rawTimes, offsets);
        }
      }
    }

    return null;
  }

  /// Applies manual minute offsets defined by the user in Settings
  static Map<String, String> applyUserOffsets(Map<String, String> times, Map<String, int> offsets) {
    if (offsets.isEmpty) return Map.from(times);
    final Map<String, String> result = {};
    for (final entry in times.entries) {
      final key = entry.key;
      final val = entry.value;
      final userOffset = offsets[key] ?? 0;
      if (userOffset == 0) {
        result[key] = val;
      } else {
        final parts = val.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final totalMinutes = (h * 60 + m + userOffset) % (24 * 60);
          final adjustedMinutes = totalMinutes < 0 ? totalMinutes + 24 * 60 : totalMinutes;
          final newH = (adjustedMinutes ~/ 60).toString().padLeft(2, '0');
          final newM = (adjustedMinutes % 60).toString().padLeft(2, '0');
          result[key] = '$newH:$newM';
        } else {
          result[key] = val;
        }
      }
    }
    return result;
  }

  /// Calibrations for Kurdistan cities to align astronomical times with official Ministry of Endowments schedules
  static const Map<String, Map<String, int>> kurdistanCalibrations = {
    'sulaymaniyah': {'Fajr': 5, 'Sunrise': 1, 'Dhuhr': 5, 'Asr': 1, 'Maghrib': 7, 'Isha': 2},
    'erbil': {'Fajr': 0, 'Sunrise': 6, 'Dhuhr': 10, 'Asr': 4, 'Maghrib': 5, 'Isha': 0},
    'kirkuk': {'Fajr': 0, 'Sunrise': -3, 'Dhuhr': 3, 'Asr': 3, 'Maghrib': 5, 'Isha': 0},
    'halabja': {'Fajr': 3, 'Sunrise': 7, 'Dhuhr': 4, 'Asr': 5, 'Maghrib': 6, 'Isha': -1},
    'duhok': {'Fajr': 1, 'Sunrise': 3, 'Dhuhr': 7, 'Asr': 7, 'Maghrib': 6, 'Isha': 8},
    'zakho': {'Fajr': 1, 'Sunrise': 3, 'Dhuhr': 7, 'Asr': 7, 'Maghrib': 6, 'Isha': 8},
    'kalar': {'Fajr': 5, 'Sunrise': 4, 'Dhuhr': 3, 'Asr': 4, 'Maghrib': 4, 'Isha': -1},
    'chamchamal': {'Fajr': 9, 'Sunrise': 2, 'Dhuhr': 4, 'Asr': 1, 'Maghrib': 6, 'Isha': 6},
    'akre': {'Fajr': 7, 'Sunrise': 7, 'Dhuhr': 5, 'Asr': 7, 'Maghrib': 6, 'Isha': -1},
    'darbandikhan': {'Fajr': 5, 'Sunrise': 1, 'Dhuhr': 5, 'Asr': 1, 'Maghrib': 7, 'Isha': 2},
    'rania': {'Fajr': 7, 'Sunrise': 2, 'Dhuhr': 5, 'Asr': 2, 'Maghrib': 8, 'Isha': 2},
    'qaladiza': {'Fajr': 6, 'Sunrise': 1, 'Dhuhr': 4, 'Asr': 1, 'Maghrib': 7, 'Isha': 1},
    'koya': {'Fajr': 1, 'Sunrise': 7, 'Dhuhr': 10, 'Asr': 4, 'Maghrib': 6, 'Isha': 0},
    'kifri': {'Fajr': 5, 'Sunrise': 5, 'Dhuhr': 4, 'Asr': 4, 'Maghrib': 4, 'Isha': -1},
    'bardarash': {'Fajr': 5, 'Sunrise': 5, 'Dhuhr': 4, 'Asr': 6, 'Maghrib': 5, 'Isha': -1},
    'soran': {'Fajr': 0, 'Sunrise': 6, 'Dhuhr': 10, 'Asr': 4, 'Maghrib': 5, 'Isha': 0},
    'mosul': {'Fajr': 0, 'Sunrise': -2, 'Dhuhr': 3, 'Asr': 3, 'Maghrib': 5, 'Isha': 0},
  };

  static bool _tzInitialized = false;
  static void _ensureTimeZones() {
    if (!_tzInitialized) {
      try {
        tz.initializeTimeZones();
        _tzInitialized = true;
      } catch (_) {}
    }
  }

  static const Map<String, String> _countryToTimezone = {
    'IQ': 'Asia/Baghdad',
    'SA': 'Asia/Riyadh',
    'AE': 'Asia/Dubai',
    'QA': 'Asia/Qatar',
    'KW': 'Asia/Kuwait',
    'BH': 'Asia/Bahrain',
    'OM': 'Asia/Muscat',
    'TR': 'Europe/Istanbul',
    'IR': 'Asia/Tehran',
    'SY': 'Asia/Damascus',
    'PS': 'Asia/Gaza',
    'JO': 'Asia/Amman',
    'LB': 'Asia/Beirut',
    'EG': 'Africa/Cairo',
    'YE': 'Asia/Aden',
    'SD': 'Africa/Khartoum',
    'MA': 'Africa/Casablanca',
    'DZ': 'Africa/Algiers',
    'TN': 'Africa/Tunis',
    'LY': 'Africa/Tripoli',
    'GB': 'Europe/London',
    'DE': 'Europe/Berlin',
    'FR': 'Europe/Paris',
    'IT': 'Europe/Rome',
    'ES': 'Europe/Madrid',
    'NL': 'Europe/Amsterdam',
    'BE': 'Europe/Brussels',
    'SE': 'Europe/Stockholm',
    'NO': 'Europe/Oslo',
    'DK': 'Europe/Copenhagen',
    'FI': 'Europe/Helsinki',
    'CH': 'Europe/Zurich',
    'AT': 'Europe/Vienna',
    'GR': 'Europe/Athens',
    'PL': 'Europe/Warsaw',
    'CZ': 'Europe/Prague',
    'HU': 'Europe/Budapest',
    'RO': 'Europe/Bucharest',
    'BG': 'Europe/Sofia',
    'IE': 'Europe/Dublin',
    'PT': 'Europe/Lisbon',
    'UA': 'Europe/Kyiv',
    'AL': 'Europe/Tirane',
    'BA': 'Europe/Sarajevo',
    'HR': 'Europe/Zagreb',
    'RS': 'Europe/Belgrade',
    'MK': 'Europe/Skopje',
    'ME': 'Europe/Podgorica',
    'XK': 'Europe/Belgrade',
    'CY': 'Asia/Nicosia',
    'MT': 'Europe/Malta',
    'IS': 'Atlantic/Reykjavik',
    'LU': 'Europe/Luxembourg',
    'SK': 'Europe/Bratislava',
    'SI': 'Europe/Ljubljana',
    'EE': 'Europe/Tallinn',
    'LV': 'Europe/Riga',
    'LT': 'Europe/Vilnius',
    'BY': 'Europe/Minsk',
    'MD': 'Europe/Chisinau',
    'PK': 'Asia/Karachi',
    'IN': 'Asia/Kolkata',
    'BD': 'Asia/Dhaka',
    'AF': 'Asia/Kabul',
    'AZ': 'Asia/Baku',
    'UZ': 'Asia/Tashkent',
    'KZ': 'Asia/Almaty',
    'TM': 'Asia/Ashgabat',
    'KG': 'Asia/Bishkek',
    'TJ': 'Asia/Dushanbe',
    'MY': 'Asia/Kuala_Lumpur',
    'ID': 'Asia/Jakarta',
    'JP': 'Asia/Tokyo',
    'KR': 'Asia/Seoul',
    'CN': 'Asia/Shanghai',
    'TH': 'Asia/Bangkok',
    'VN': 'Asia/Ho_Chi_Minh',
    'PH': 'Asia/Manila',
    'SG': 'Asia/Singapore',
    'LK': 'Asia/Colombo',
    'MM': 'Asia/Yangon',
    'NP': 'Asia/Kathmandu',
    'MV': 'Indian/Maldives',
    'BN': 'Asia/Brunei',
    'KH': 'Asia/Phnom_Penh',
    'MN': 'Asia/Ulaanbaatar',
    'TW': 'Asia/Taipei',
    'NZ': 'Pacific/Auckland',
    'NG': 'Africa/Lagos',
    'ET': 'Africa/Addis_Ababa',
    'ZA': 'Africa/Johannesburg',
    'KE': 'Africa/Nairobi',
    'TZ': 'Africa/Dar_es_Salaam',
    'UG': 'Africa/Kampala',
    'GH': 'Africa/Accra',
    'SN': 'Africa/Dakar',
    'CI': 'Africa/Abidjan',
    'ML': 'Africa/Bamako',
    'NE': 'Africa/Niamey',
    'BF': 'Africa/Ouagadougou',
    'GN': 'Africa/Conakry',
    'TD': 'Africa/Ndjamena',
    'ZW': 'Africa/Harare',
    'RW': 'Africa/Kigali',
    'BI': 'Africa/Bujumbura',
    'CM': 'Africa/Douala',
    'AO': 'Africa/Luanda',
    'MZ': 'Africa/Maputo',
    'ZM': 'Africa/Lusaka',
    'MW': 'Africa/Blantyre',
    'MG': 'Indian/Antananarivo',
    'SO': 'Africa/Mogadishu',
    'DJ': 'Africa/Djibouti',
    'MR': 'Africa/Nouakchott',
    'MX': 'America/Mexico_City',
    'BR': 'America/Sao_Paulo',
    'AR': 'America/Argentina/Buenos_Aires',
    'CL': 'America/Santiago',
    'CO': 'America/Bogota',
    'PE': 'America/Lima',
    'VE': 'America/Caracas',
    'CU': 'America/Havana',
    'DO': 'America/Santo_Domingo',
    'EC': 'America/Guayaquil',
    'GT': 'America/Guatemala',
    'PA': 'America/Panama',
    'BO': 'America/La_Paz',
    'CR': 'America/Costa_Rica',
    'UY': 'America/Montevideo',
    'PY': 'America/Asuncion',
    'JM': 'America/Jamaica',
    'TT': 'America/Port_of_Spain',
  };

  static const Map<String, String> _cityIdToTimezone = {
    'washington-dc': 'America/New_York',
    'new-york': 'America/New_York',
    'chicago': 'America/Chicago',
    'los-angeles': 'America/Los_Angeles',
    'san-francisco': 'America/Los_Angeles',
    'houston': 'America/Chicago',
    'toronto': 'America/Toronto',
    'montreal': 'America/Toronto',
    'vancouver': 'America/Vancouver',
    'london': 'Europe/London',
    'birmingham': 'Europe/London',
    'manchester': 'Europe/London',
    'edinburgh': 'Europe/London',
    'glasgow': 'Europe/London',
    'berlin': 'Europe/Berlin',
    'munich': 'Europe/Berlin',
    'frankfurt': 'Europe/Berlin',
    'hamburg': 'Europe/Berlin',
    'paris': 'Europe/Paris',
    'marseille': 'Europe/Paris',
    'lyon': 'Europe/Paris',
    'stockholm': 'Europe/Stockholm',
    'gothenburg': 'Europe/Stockholm',
    'malmo': 'Europe/Stockholm',
    'oslo': 'Europe/Oslo',
    'copenhagen': 'Europe/Copenhagen',
    'helsinki': 'Europe/Helsinki',
    'amsterdam': 'Europe/Amsterdam',
    'brussels': 'Europe/Brussels',
    'vienna': 'Europe/Vienna',
    'zurich': 'Europe/Zurich',
    'geneva': 'Europe/Zurich',
    'rome': 'Europe/Rome',
    'milan': 'Europe/Rome',
    'madrid': 'Europe/Madrid',
    'barcelona': 'Europe/Madrid',
    'athens': 'Europe/Athens',
    'istanbul': 'Europe/Istanbul',
    'ankara': 'Europe/Istanbul',
    'izmir': 'Europe/Istanbul',
    'tehran': 'Asia/Tehran',
    'tabriz': 'Asia/Tehran',
    'isfahan': 'Asia/Tehran',
    'shiraz': 'Asia/Tehran',
    'makkah': 'Asia/Riyadh',
    'madinah': 'Asia/Riyadh',
    'riyadh': 'Asia/Riyadh',
    'jeddah': 'Asia/Riyadh',
    'dubai': 'Asia/Dubai',
    'abu-dhabi': 'Asia/Dubai',
    'doha': 'Asia/Qatar',
    'kuwait-city': 'Asia/Kuwait',
    'manama': 'Asia/Bahrain',
    'muscat': 'Asia/Muscat',
    'cairo': 'Africa/Cairo',
    'alexandria': 'Africa/Cairo',
    'beirut': 'Asia/Beirut',
    'amman': 'Asia/Amman',
    'damascus': 'Asia/Damascus',
    'aleppo': 'Asia/Damascus',
    'jerusalem': 'Asia/Gaza',
    'tokyo': 'Asia/Tokyo',
    'seoul': 'Asia/Seoul',
    'beijing': 'Asia/Shanghai',
    'shanghai': 'Asia/Shanghai',
    'sydney': 'Australia/Sydney',
    'melbourne': 'Australia/Sydney',
    'brisbane': 'Australia/Brisbane',
    'perth': 'Australia/Perth',
  };

  static String? resolveTimezoneName({
    String? countryCode,
    required double latitude,
    required double longitude,
    String? cityId,
  }) {
    if (cityId != null) {
      final cId = cityId.toLowerCase();
      if (cityIdToAwqafKey.containsKey(cId) || kurdistanCalibrations.containsKey(cId)) {
        return 'Asia/Baghdad';
      }
      final mapped = _cityIdToTimezone[cId];
      if (mapped != null) return mapped;
    }

    final code = (countryCode ?? '').toUpperCase();
    if (code == 'US') {
      if (longitude >= -86) return 'America/New_York';
      if (longitude >= -102) return 'America/Chicago';
      if (longitude >= -115) return 'America/Denver';
      return 'America/Los_Angeles';
    }
    if (code == 'CA') {
      if (longitude >= -70) return 'America/Halifax';
      if (longitude >= -85) return 'America/Toronto';
      if (longitude >= -102) return 'America/Winnipeg';
      if (longitude >= -115) return 'America/Edmonton';
      return 'America/Vancouver';
    }
    if (code == 'AU') {
      if (longitude >= 140) return 'Australia/Sydney';
      if (longitude >= 129) return 'Australia/Adelaide';
      return 'Australia/Perth';
    }
    if (code == 'RU') {
      if (longitude <= 45) return 'Europe/Moscow';
      if (longitude <= 65) return 'Asia/Yekaterinburg';
      if (longitude <= 85) return 'Asia/Omsk';
      if (longitude <= 95) return 'Asia/Krasnoyarsk';
      if (longitude <= 110) return 'Asia/Irkutsk';
      if (longitude <= 130) return 'Asia/Yakutsk';
      return 'Asia/Vladivostok';
    }

    return _countryToTimezone[code];
  }

  static Map<String, String> calculateTimes({
    required double latitude,
    required double longitude,
    required String method,
    required String asrMadhab,
    required Map<String, int> offsets,
    String? cityId,
    String? countryCode,
    DateTime? targetDate,
  }) {
    // 1. Always prioritize the official Kurdistan Ministry of Awqaf database!
    if (cityId != null) {
      final official = getOfficialAwqafTimes(
        cityId: cityId,
        targetDate: targetDate,
        offsets: offsets,
      );
      if (official != null) {
        return official;
      }
    }
    try {
      final coordinates = Coordinates(latitude, longitude);
      final date = DateComponents.from(targetDate ?? DateTime.now());

      final hasKurdistanCalibration = cityId != null && kurdistanCalibrations.containsKey(cityId.toLowerCase());

      CalculationParameters params;
      final cCode = (countryCode ?? '').toUpperCase();
      final isIraqOrKurdistan = cCode == 'IQ' ||
          hasKurdistanCalibration ||
          (cityId != null && cityIdToAwqafKey.containsKey(cityId.toLowerCase()));

      if (isIraqOrKurdistan) {
        params = CalculationMethod.muslim_world_league.getParameters();
      } else {
        // Automatically determine official calculation parameters for the country
        if (cCode == 'SA' || cCode == 'YE' || cCode == 'OM' || method == 'UmmAlQura') {
          params = CalculationMethod.umm_al_qura.getParameters();
        } else if (cCode == 'AE') {
          params = CalculationMethod.dubai.getParameters();
        } else if (cCode == 'QA') {
          params = CalculationMethod.qatar.getParameters();
        } else if (cCode == 'KW') {
          params = CalculationMethod.kuwait.getParameters();
        } else if (cCode == 'TR' || method == 'Diyanet') {
          params = CalculationMethod.turkey.getParameters();
        } else if (['EG', 'JO', 'PS', 'SY', 'LB', 'SD', 'LY', 'DZ', 'MA', 'TN'].contains(cCode) || method == 'Egyptian') {
          params = CalculationMethod.egyptian.getParameters();
        } else if (['US', 'CA', 'MX'].contains(cCode) || method == 'ISNA') {
          params = CalculationMethod.north_america.getParameters();
        } else if (['PK', 'IN', 'BD', 'AF'].contains(cCode) || method == 'Karachi') {
          params = CalculationMethod.karachi.getParameters();
        } else if (['SG', 'MY', 'ID', 'BN'].contains(cCode)) {
          params = CalculationMethod.singapore.getParameters();
        } else if (cCode == 'IR' || method == 'Tehran') {
          params = CalculationMethod.tehran.getParameters();
        } else {
          params = CalculationMethod.muslim_world_league.getParameters();
        }
      }

      params.madhab = asrMadhab == 'Hanafi' ? Madhab.hanafi : Madhab.shafi;

      // Safe twilight calculation for northern latitudes (above 48 degrees)
      if (latitude.abs() > 48.0) {
        params.highLatitudeRule = HighLatitudeRule.seventh_of_the_night;
      }

      final prayerTimes = PrayerTimes(coordinates, date, params);

      final Map<String, int> calibration = hasKurdistanCalibration
          ? (kurdistanCalibrations[cityId.toLowerCase()] ?? const {})
          : const {};

      _ensureTimeZones();
      final tzName = resolveTimezoneName(
        countryCode: countryCode,
        latitude: latitude,
        longitude: longitude,
        cityId: cityId,
      );

      tz.Location? location;
      if (tzName != null) {
        try {
          location = tz.getLocation(tzName);
        } catch (_) {}
      }

      String fmt(DateTime? t, String key) {
        if (t == null) return '--:--';
        final calOffset = calibration[key] ?? 0;
        final userOffset = offsets[key] ?? 0;
        final totalOffset = calOffset + userOffset;

        final adjusted = totalOffset == 0 ? t : t.add(Duration(minutes: totalOffset));
        // Round to the nearest minute to prevent being up to 59 seconds early
        final rounded = adjusted.add(const Duration(seconds: 30));

        final DateTime localT;
        if (location != null) {
          localT = tz.TZDateTime.from(rounded, location);
        } else {
          final solarHourOffset = (longitude / 15.0).round();
          localT = rounded.toUtc().add(Duration(hours: solarHourOffset));
        }

        final hour = localT.hour.toString().padLeft(2, '0');
        final min = localT.minute.toString().padLeft(2, '0');
        return '$hour:$min';
      }

      return {
        'Fajr': fmt(prayerTimes.fajr, 'Fajr'),
        'Sunrise': fmt(prayerTimes.sunrise, 'Sunrise'),
        'Dhuhr': fmt(prayerTimes.dhuhr, 'Dhuhr'),
        'Asr': fmt(prayerTimes.asr, 'Asr'),
        'Maghrib': fmt(prayerTimes.maghrib, 'Maghrib'),
        'Isha': fmt(prayerTimes.isha, 'Isha'),
      };
    } catch (e) {
      debugPrint('[PrayerService] Error calculating times: $e');
      return {
        'Fajr': '04:15',
        'Sunrise': '05:45',
        'Dhuhr': '12:10',
        'Asr': '15:40',
        'Maghrib': '18:25',
        'Isha': '19:45',
      };
    }
  }

  static Map<String, String> getNextPrayer(Map<String, String> times) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    const prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    for (final name in prayerOrder) {
      final val = times[name];
      if (val == null) continue;
      final parts = val.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final tMinutes = h * 60 + m;
        if (tMinutes > nowMinutes) {
          return {'name': name, 'time': val, 'isTomorrow': 'false'};
        }
      }
    }
    return {'name': 'Fajr', 'time': times['Fajr'] ?? '04:30', 'isTomorrow': 'true'};
  }
}
