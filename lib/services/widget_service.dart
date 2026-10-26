import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_service.dart';
import 'prayer_service.dart';

class WidgetService {
  static const String appGroupId = 'group.com.islamicapp.app';
  static const String androidWidgetName = 'PrayerWidgetProvider';
  static const String qualifiedAndroidWidgetName =
      'com.islamicapp.app.islamic_app_flutter.PrayerWidgetProvider';
  static const String iOSWidgetName = 'PrayerWidget';

  /// Update the home screen widget with current prayer times and next prayer
  static Future<void> updatePrayerWidget({
    required String cityName,
    required Map<String, String> prayerTimes,
    required Map<String, String> nextPrayerInfo,
    String language = 'ku',
  }) async {
    // Widgets are only supported on physical mobile platforms (Android and iOS)
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    try {
      // App Group ID is specifically an iOS WidgetKit requirement
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await HomeWidget.setAppGroupId(appGroupId);
        } catch (e) {
          debugPrint('[WidgetService] setAppGroupId warning: $e');
        }
      }

      final localizedPrayerNames = {
        'ku': {
          'Fajr': 'بەیانی',
          'Sunrise': 'ڕۆژهەڵات',
          'Dhuhr': 'نیوەڕۆ',
          'Asr': 'عەسر',
          'Maghrib': 'مەغریب',
          'Isha': 'عیشا',
        },
        'ar': {
          'Fajr': 'الفجر',
          'Sunrise': 'الشروق',
          'Dhuhr': 'الظهر',
          'Asr': 'العصر',
          'Maghrib': 'المغرب',
          'Isha': 'العشاء',
        },
        'en': {
          'Fajr': 'Fajr',
          'Sunrise': 'Sunrise',
          'Dhuhr': 'Dhuhr',
          'Asr': 'Asr',
          'Maghrib': 'Maghrib',
          'Isha': 'Isha',
        },
      };

      final localizedTitles = {
        'ku': 'کاتەکانی بانگ',
        'ar': 'مواقيت الصلاة',
        'en': 'Prayer Times',
      };

      final localizedNextLabels = {
        'ku': 'نوێژی داهاتوو',
        'ar': 'الصلاة القادمة',
        'en': 'Next Prayer',
      };

      final langMap = localizedPrayerNames[language] ?? localizedPrayerNames['ku']!;
      final appTitle = localizedTitles[language] ?? localizedTitles['ku']!;
      final nextLabel = localizedNextLabels[language] ?? localizedNextLabels['ku']!;

      final nextNameKey = nextPrayerInfo['name'] ?? 'Fajr';
      final nextTime = nextPrayerInfo['time'] ?? '--:--';
      final isTomorrow = nextPrayerInfo['isTomorrow'] == 'true';
      final nextPrayerDisplayName = langMap[nextNameKey] ?? nextNameKey;

      // Calculate remaining countdown text
      final remainingText = _calculateRemaining(nextTime, isTomorrow, language);

      await HomeWidget.saveWidgetData<String>('widget_city', cityName);
      await HomeWidget.saveWidgetData<String>('widget_app_title', appTitle);
      await HomeWidget.saveWidgetData<String>('widget_next_prayer', '$nextLabel: $nextPrayerDisplayName');
      await HomeWidget.saveWidgetData<String>('widget_next_name', nextNameKey);
      await HomeWidget.saveWidgetData<String>('widget_next_time', nextTime);
      await HomeWidget.saveWidgetData<String>('widget_remaining', remainingText);

      await HomeWidget.saveWidgetData<String>('widget_fajr_name', langMap['Fajr'] ?? 'بەیانی');
      await HomeWidget.saveWidgetData<String>('widget_dhuhr_name', langMap['Dhuhr'] ?? 'نیوەڕۆ');
      await HomeWidget.saveWidgetData<String>('widget_asr_name', langMap['Asr'] ?? 'عەسر');
      await HomeWidget.saveWidgetData<String>('widget_maghrib_name', langMap['Maghrib'] ?? 'مەغریب');
      await HomeWidget.saveWidgetData<String>('widget_isha_name', langMap['Isha'] ?? 'عیشا');

      await HomeWidget.saveWidgetData<String>('widget_fajr', prayerTimes['Fajr'] ?? '--:--');
      await HomeWidget.saveWidgetData<String>('widget_dhuhr', prayerTimes['Dhuhr'] ?? '--:--');
      await HomeWidget.saveWidgetData<String>('widget_asr', prayerTimes['Asr'] ?? '--:--');
      await HomeWidget.saveWidgetData<String>('widget_maghrib', prayerTimes['Maghrib'] ?? '--:--');
      await HomeWidget.saveWidgetData<String>('widget_isha', prayerTimes['Isha'] ?? '--:--');

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: qualifiedAndroidWidgetName,
        iOSName: iOSWidgetName,
      );

      // Schedule background updates at prayer times for exact notifications & countdown update
      try {
        final now = DateTime.now();
        final scheduleTimes = <DateTime>[];
        for (final entry in prayerTimes.entries) {
          if (entry.key == 'Sunrise') continue;
          final timeParts = entry.value.split(':');
          if (timeParts.length == 2) {
            final h = int.tryParse(timeParts[0]);
            final m = int.tryParse(timeParts[1]);
            if (h != null && m != null) {
              final target = DateTime(now.year, now.month, now.day, h, m);
              if (target.isAfter(now)) {
                scheduleTimes.add(target);
                scheduleTimes.add(target.add(const Duration(minutes: 1)));
              }
            }
          }
        }
        if (scheduleTimes.isNotEmpty) {
          scheduleTimes.sort();
          await HomeWidget.scheduleWidgetUpdates(
            scheduleTimes,
            androidName: androidWidgetName,
            qualifiedAndroidName: qualifiedAndroidWidgetName,
          );
        }
      } catch (e) {
        debugPrint('[WidgetService] scheduleWidgetUpdates error: $e');
      }
    } catch (e) {
      debugPrint('[WidgetService] Error updating home widget: $e');
    }
  }

  /// Initial startup helper to make sure the home widget has fresh data immediately
  static Future<void> updateFromPreferences(SharedPreferences prefs) async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      final cityId = prefs.getString('userCityId') ?? 'erbil';
      final lang = prefs.getString('language') ?? 'ku';
      final method = prefs.getString('calculationMethod') ?? 'KRG';
      final asrMadhab = prefs.getString('asrMadhab') ?? 'Shafi';
      final now = DateTime.now();

      final cities = await DataService.loadCities();
      final activeCity = cities.firstWhere(
        (c) => c.id == cityId,
        orElse: () => cities.first,
      );

      final Map<String, int> offsets = {
        'Fajr': 0,
        'Sunrise': 0,
        'Dhuhr': 0,
        'Asr': 0,
        'Maghrib': 0,
        'Isha': 0,
      };
      final rawOffsets = prefs.getString('prayerOffsets');
      if (rawOffsets != null) {
        try {
          final decoded = jsonDecode(rawOffsets) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            if (value is num) offsets[key] = value.toInt();
          });
        } catch (_) {}
      }

      final times = PrayerService.calculateTimes(
        latitude: activeCity.lat,
        longitude: activeCity.lng,
        method: method,
        asrMadhab: asrMadhab,
        offsets: offsets,
        cityId: activeCity.id,
        countryCode: activeCity.country,
        targetDate: now,
      );

      final nextPrayer = PrayerService.getNextPrayer(times);
      final cityName = lang == 'ku'
          ? activeCity.ku
          : (lang == 'ar' ? activeCity.ar : activeCity.en);

      await updatePrayerWidget(
        cityName: cityName,
        prayerTimes: times,
        nextPrayerInfo: nextPrayer,
        language: lang,
      );
    } catch (e) {
      debugPrint('[WidgetService] updateFromPreferences error: $e');
    }
  }

  static String _calculateRemaining(String targetTime, bool isTomorrow, String language) {
    try {
      final now = DateTime.now();
      final parts = targetTime.split(':');
      if (parts.length != 2) return '';
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;

      var target = DateTime(now.year, now.month, now.day, h, m);
      if (isTomorrow || target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }

      final diff = target.difference(now);
      final diffMinutes = diff.inMinutes;

      if (language == 'ar') {
        if (diffMinutes <= 0) return 'حان الآن موعد الأذان';
        final hours = diffMinutes ~/ 60;
        final mins = diffMinutes % 60;
        if (hours > 0) {
          return 'متبقي $hours ساعة و $mins دقيقة';
        } else {
          return 'متبقي $mins دقيقة';
        }
      } else if (language == 'en') {
        if (diffMinutes <= 0) return 'It is time for Adhan';
        final hours = diffMinutes ~/ 60;
        final mins = diffMinutes % 60;
        if (hours > 0) {
          return 'in $hours hr $mins min';
        } else {
          return 'in $mins min';
        }
      } else {
        // Default Kurdish
        if (diffMinutes <= 0) return 'کاتی بانگ هاتووە';
        final hours = diffMinutes ~/ 60;
        final mins = diffMinutes % 60;
        if (hours > 0) {
          return 'ماوە $hours کاتژمێر و $mins خولەک';
        } else {
          return 'ماوە $mins خولەک';
        }
      }
    } catch (_) {
      return '';
    }
  }
}
