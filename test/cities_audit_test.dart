import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_app_flutter/models/city.dart';
import 'package:islamic_app_flutter/services/prayer_service.dart';
import 'package:islamic_app_flutter/services/data_service.dart';

void main() {
  test('Complete audit of all 401 cities for data integrity and prayer calculations', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await DataService.loadAwqafPrayerDatabase();
    final file = File('assets/data/cities.json');
    expect(file.existsSync(), isTrue);

    final jsonStr = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    expect(jsonList.length, greaterThanOrEqualTo(350));

    final cities = jsonList.map((j) => City.fromJson(j)).toList();
    final seenIds = <String>{};
    final now = DateTime.now();

    int awqafMatches = 0;
    int calculatedCities = 0;

    for (final city in cities) {
      // 1. Unique ID
      expect(seenIds.contains(city.id), isFalse, reason: 'Duplicate ID: ${city.id}');
      seenIds.add(city.id);

      // 2. Valid coordinates
      expect(city.lat, inInclusiveRange(-90.0, 90.0), reason: 'Bad lat for ${city.id}');
      expect(city.lng, inInclusiveRange(-180.0, 180.0), reason: 'Bad lng for ${city.id}');
      expect(city.lat != 0.0 || city.lng != 0.0, isTrue, reason: 'Zero coords for ${city.id}');

      // 3. Complete trilingual names
      expect(city.ku.isNotEmpty, isTrue, reason: 'Empty ku name for ${city.id}');
      expect(city.ar.isNotEmpty, isTrue, reason: 'Empty ar name for ${city.id}');
      expect(city.en.isNotEmpty, isTrue, reason: 'Empty en name for ${city.id}');
      expect(city.country.isNotEmpty, isTrue, reason: 'Empty country for ${city.id}');
      expect(city.countryKu.isNotEmpty, isTrue, reason: 'Empty countryKu for ${city.id}');

      // 4. Test prayer calculations
      final times = PrayerService.calculateTimes(
        latitude: city.lat,
        longitude: city.lng,
        method: city.country == 'IQ' ? 'KRG' : 'MuslimWorldLeague',
        asrMadhab: 'Shafi',
        offsets: const {},
        cityId: city.id,
        countryCode: city.country,
        targetDate: now,
      );

      final fajr = times['Fajr'];
      final sunrise = times['Sunrise'];
      final dhuhr = times['Dhuhr'];
      final asr = times['Asr'];
      final maghrib = times['Maghrib'];
      final isha = times['Isha'];

      expect(fajr, isNotNull, reason: 'Fajr null for ${city.id}');
      expect(sunrise, isNotNull, reason: 'Sunrise null for ${city.id}');
      expect(dhuhr, isNotNull, reason: 'Dhuhr null for ${city.id}');
      expect(asr, isNotNull, reason: 'Asr null for ${city.id}');
      expect(maghrib, isNotNull, reason: 'Maghrib null for ${city.id}');
      expect(isha, isNotNull, reason: 'Isha null for ${city.id}');

      final timePattern = RegExp(r'^\d{2}:\d{2}$');
      expect(timePattern.hasMatch(fajr!), isTrue, reason: 'Bad Fajr format: $fajr in ${city.id}');
      expect(timePattern.hasMatch(sunrise!), isTrue, reason: 'Bad Sunrise format: $sunrise in ${city.id}');
      expect(timePattern.hasMatch(dhuhr!), isTrue, reason: 'Bad Dhuhr format: $dhuhr in ${city.id}');
      expect(timePattern.hasMatch(asr!), isTrue, reason: 'Bad Asr format: $asr in ${city.id}');
      expect(timePattern.hasMatch(maghrib!), isTrue, reason: 'Bad Maghrib format: $maghrib in ${city.id}');
      expect(timePattern.hasMatch(isha!), isTrue, reason: 'Bad Isha format: $isha in ${city.id}');

      // Verify chronological order for normal latitudes
      if (city.lat.abs() < 55.0) {
        int toMins(String t) {
          final p = t.split(':');
          return int.parse(p[0]) * 60 + int.parse(p[1]);
        }
        final fM = toMins(fajr);
        final sM = toMins(sunrise);
        final dM = toMins(dhuhr);
        final aM = toMins(asr);
        final mM = toMins(maghrib);
        final iM = toMins(isha);

        expect(fM < sM, isTrue, reason: 'Fajr ($fajr) >= Sunrise ($sunrise) in ${city.id}');
        expect(sM < dM, isTrue, reason: 'Sunrise ($sunrise) >= Dhuhr ($dhuhr) in ${city.id}');
        expect(dM < aM, isTrue, reason: 'Dhuhr ($dhuhr) >= Asr ($asr) in ${city.id}');
        expect(aM < mM, isTrue, reason: 'Asr ($asr) >= Maghrib ($maghrib) in ${city.id}');
        expect(mM < iM, isTrue, reason: 'Maghrib ($maghrib) >= Isha ($isha) in ${city.id}');
      }

      final awqafKey = PrayerService.cityIdToAwqafKey[city.id.toLowerCase()];
      if (city.country.toUpperCase() == 'IQ' || awqafKey != null) {
        final awqafTimes = PrayerService.getOfficialAwqafTimes(cityId: city.id, targetDate: now);
        if (awqafTimes != null) {
          awqafMatches++;
        } else {
          calculatedCities++;
        }
      } else {
        calculatedCities++;
      }
    }

    print('AUDIT PASSED: ${cities.length} cities verified. Awqaf exact: $awqafMatches, Calculated: $calculatedCities');
  });

  test('High latitude cities calculate valid times even on summer solstice (June 21)', () {
    final highLatCities = [
      {'name': 'Reykjavik', 'lat': 64.1466, 'lng': -21.9426},
      {'name': 'Oslo', 'lat': 59.9139, 'lng': 10.7522},
      {'name': 'Stockholm', 'lat': 59.3293, 'lng': 18.0686},
      {'name': 'Helsinki', 'lat': 60.1699, 'lng': 24.9384},
      {'name': 'London', 'lat': 51.5074, 'lng': -0.1278},
    ];

    final solstice = DateTime(2026, 6, 21);
    for (final c in highLatCities) {
      final times = PrayerService.calculateTimes(
        latitude: c['lat'] as double,
        longitude: c['lng'] as double,
        method: 'MuslimWorldLeague',
        asrMadhab: 'Shafi',
        offsets: const {},
        targetDate: solstice,
      );

      print('${c['name']} on June 21: $times');
      for (final val in times.values) {
        expect(val, isNotNull);
        expect(val != '--:--', isTrue, reason: 'Returned --:-- for ${c['name']}');
      }
    }
  });

  test('Check key world cities calculated times on October 15', () {
    final today = DateTime(2026, 10, 15);
    final cities = [
      {'id': 'makkah', 'country': 'SA', 'lat': 21.4225, 'lng': 39.8262, 'method': 'UmmAlQura'},
      {'id': 'dubai', 'country': 'AE', 'lat': 25.2048, 'lng': 55.2708, 'method': 'UmmAlQura'},
      {'id': 'cairo', 'country': 'EG', 'lat': 30.0444, 'lng': 31.2357, 'method': 'Egyptian'},
      {'id': 'istanbul', 'country': 'TR', 'lat': 41.0082, 'lng': 28.9784, 'method': 'Diyanet'},
      {'id': 'london', 'country': 'GB', 'lat': 51.5074, 'lng': -0.1278, 'method': 'MuslimWorldLeague'},
      {'id': 'berlin', 'country': 'DE', 'lat': 52.5200, 'lng': 13.4050, 'method': 'MuslimWorldLeague'},
      {'id': 'washington-dc', 'country': 'US', 'lat': 38.9072, 'lng': -77.0369, 'method': 'ISNA'},
    ];

    for (final c in cities) {
      final t = PrayerService.calculateTimes(
        latitude: c['lat'] as double,
        longitude: c['lng'] as double,
        method: c['method'] as String,
        asrMadhab: 'Shafi',
        offsets: const {},
        cityId: c['id'] as String,
        countryCode: c['country'] as String,
        targetDate: today,
      );
      print('${c['id']} calculated: $t');
    }
  });
}
