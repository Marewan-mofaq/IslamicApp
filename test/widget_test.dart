import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:islamic_app_flutter/main.dart';
import 'package:islamic_app_flutter/providers/settings_provider.dart';
import 'package:islamic_app_flutter/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:audio_service/audio_service.dart';
import 'package:islamic_app_flutter/services/quran_audio_handler.dart';
import 'package:islamic_app_flutter/services/widget_service.dart';
import 'package:islamic_app_flutter/services/location_service.dart';
import 'package:islamic_app_flutter/models/city.dart';
import 'package:islamic_app_flutter/services/prayer_service.dart';
import 'package:islamic_app_flutter/services/aladhan_service.dart';
import 'package:islamic_app_flutter/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:islamic_app_flutter/screens/main_navigation.dart';
import 'package:islamic_app_flutter/screens/surah_view_screen.dart';
import 'package:islamic_app_flutter/screens/quran_screen.dart';
import 'package:islamic_app_flutter/services/data_service.dart';
import 'package:islamic_app_flutter/providers/activity_provider.dart';

void main() {
  testWidgets('MyApp shows OnboardingScreen on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(MainNavigation), findsNothing);
  });

  testWidgets('MyApp shows MainNavigation when onboarding is completed', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'is_first_launch_done': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MainNavigation), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  test('SettingsProvider handles regular and Fajr adhan voices separately', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);

    // Initial default values
    expect(notifier.state.selectedAdhanVoice, 'nasser');
    expect(notifier.state.selectedFajrAdhanVoice, 'mishary_fajr');

    // Update regular adhan voice
    await notifier.setSelectedAdhanVoice('ahmed');
    expect(notifier.state.selectedAdhanVoice, 'ahmed');
    expect(prefs.getString('selectedAdhanVoice'), 'ahmed');
    // Fajr voice should remain unchanged
    expect(notifier.state.selectedFajrAdhanVoice, 'mishary_fajr');

    // Update Fajr adhan voice
    await notifier.setSelectedFajrAdhanVoice('makkah_fajr');
    expect(notifier.state.selectedFajrAdhanVoice, 'makkah_fajr');
    expect(prefs.getString('selectedFajrAdhanVoice'), 'makkah_fajr');
    // Regular voice should remain unchanged
    expect(notifier.state.selectedAdhanVoice, 'ahmed');
  });

  test('NotificationService defines separate regular and Fajr voice channels', () {
    expect(NotificationService.adhanVoiceNames.containsKey('mishary'), isTrue);
    expect(NotificationService.adhanVoiceNames.containsKey('nasser'), isTrue);
    expect(NotificationService.fajrAdhanVoiceNames.containsKey('mishary_fajr'), isTrue);
    expect(NotificationService.fajrAdhanVoiceNames.containsKey('makkah_fajr'), isTrue);
    // Ensure Fajr voice is not in regular voices
    expect(NotificationService.adhanVoiceNames.containsKey('mishary_fajr'), isFalse);
  });

  test('AndroidNotificationAction compiles and has expected properties', () {
    const action = AndroidNotificationAction(
      'stop_adhan',
      'ڕاگرتنی بانگ',
      cancelNotification: true,
      showsUserInterface: true,
    );
    expect(action.id, 'stop_adhan');
    expect(action.cancelNotification, isTrue);
  });

  test('Adhkar prayer intervals correctly partition the day', () {
    const fajrMinutes = 4 * 60 + 30; // 04:30 (270)
    const asrMinutes = 15 * 60 + 30; // 15:30 (930)
    const ishaMinutes = 19 * 60 + 30; // 19:30 (1170)

    String getAdhkarInterval(int minutes) {
      if (minutes >= fajrMinutes && minutes < asrMinutes) {
        return 'morning';
      } else if (minutes >= asrMinutes && minutes < ishaMinutes) {
        return 'evening';
      } else {
        return 'bedtime';
      }
    }

    // Fajr to Asr -> Morning
    expect(getAdhkarInterval(fajrMinutes), 'morning');
    expect(getAdhkarInterval(12 * 60), 'morning'); // Dhuhr
    expect(getAdhkarInterval(asrMinutes - 1), 'morning');

    // Asr to Isha -> Evening
    expect(getAdhkarInterval(asrMinutes), 'evening');
    expect(getAdhkarInterval(18 * 60), 'evening'); // Maghrib
    expect(getAdhkarInterval(ishaMinutes - 1), 'evening');

    // Isha to Fajr -> Bedtime & Surah Al-Mulk
    expect(getAdhkarInterval(ishaMinutes), 'bedtime');
    expect(getAdhkarInterval(23 * 60), 'bedtime');
    expect(getAdhkarInterval(0), 'bedtime'); // Midnight
    expect(getAdhkarInterval(2 * 60), 'bedtime');
    expect(getAdhkarInterval(fajrMinutes - 1), 'bedtime');
  });

  test('SettingsProvider persists Quran font customization settings', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);

    // Initial defaults
    expect(notifier.state.quranArabicFontSize, 24.0);
    expect(notifier.state.quranTranslationFontSize, 15.0);
    expect(notifier.state.quranFontFamily, 'Traditional Arabic');

    // Update arabic font size
    await notifier.setQuranArabicFontSize(30.0);
    expect(notifier.state.quranArabicFontSize, 30.0);
    expect(prefs.getDouble('quranArabicFontSize'), 30.0);

    // Update translation font size
    await notifier.setQuranTranslationFontSize(18.0);
    expect(notifier.state.quranTranslationFontSize, 18.0);
    expect(prefs.getDouble('quranTranslationFontSize'), 18.0);

    // Update font family
    await notifier.setQuranFontFamily('Amiri');
    expect(notifier.state.quranFontFamily, 'Amiri');
    expect(prefs.getString('quranFontFamily'), 'Amiri');
  });

  test('NotificationService defines quran playback notification channel', () {
    expect(NotificationService.quranPlaybackChannelId, 'quran_playback_channel');
  });

  test('WidgetService defines valid iOS App Group and Widget identifiers', () {
    expect(WidgetService.appGroupId, 'group.com.islamicapp.app');
    expect(WidgetService.androidWidgetName, 'PrayerWidgetProvider');
    expect(WidgetService.qualifiedAndroidWidgetName, 'com.islamicapp.app.islamic_app_flutter.PrayerWidgetProvider');
    expect(WidgetService.iOSWidgetName, 'PrayerWidget');
  });

  test('QuranAudioHandler manages playback state and callbacks correctly', () async {
    final handler = QuranAudioHandler();
    bool played = false;
    bool paused = false;
    bool skippedNext = false;
    bool skippedPrev = false;
    bool stopped = false;

    handler.onPlayCallback = () => played = true;
    handler.onPauseCallback = () => paused = true;
    handler.onSkipToNextCallback = () => skippedNext = true;
    handler.onSkipToPreviousCallback = () => skippedPrev = true;
    handler.onStopCallback = () => stopped = true;

    await handler.play();
    expect(played, isTrue);

    await handler.pause();
    expect(paused, isTrue);

    await handler.skipToNext();
    expect(skippedNext, isTrue);

    await handler.skipToPrevious();
    expect(skippedPrev, isTrue);

    await handler.stop();
    expect(stopped, isTrue);

    handler.setQuranMediaItem(
      id: '1_1',
      title: 'الفاتحة',
      artist: 'مشاري العفاسي',
    );
    expect(handler.mediaItem.value?.title, 'الفاتحة');
    expect(handler.mediaItem.value?.artist, 'مشاري العفاسي');
  });

  test('LocationService calculates Haversine distance correctly', () {
    // Erbil coordinates
    const erbilLat = 36.1911;
    const erbilLng = 44.0092;

    // Sulaymaniyah coordinates
    const sulyLat = 35.5612;
    const sulyLng = 45.4300;

    // Distance to self is 0
    final selfDist = LocationService.calculateDistanceKm(erbilLat, erbilLng, erbilLat, erbilLng);
    expect(selfDist, 0.0);

    // Distance between Erbil and Sulaymaniyah is approximately 147-155 km
    final dist = LocationService.calculateDistanceKm(erbilLat, erbilLng, sulyLat, sulyLng);
    expect(dist, greaterThan(140.0));
    expect(dist, lessThan(160.0));
  });

  test('LocationService findNearestCity identifies closest city correctly', () {
    final cities = [
      City(id: 'erbil', ku: 'هەولێر', ar: 'أربيل', en: 'Erbil', country: 'Iraq', countryKu: 'عێراق', lat: 36.1911, lng: 44.0092),
      City(id: 'sulaymaniyah', ku: 'سلێمانی', ar: 'السليمانية', en: 'Sulaymaniyah', country: 'Iraq', countryKu: 'عێراق', lat: 35.5612, lng: 45.4300),
      City(id: 'duhok', ku: 'دهۆک', ar: 'دهوك', en: 'Duhok', country: 'Iraq', countryKu: 'عێراق', lat: 36.8679, lng: 42.9886),
    ];

    // Coordinate right outside Erbil (e.g. Shaqlawa ~36.4, 44.3)
    final nearestToErbil = LocationService.findNearestCity(36.4, 44.3, cities);
    expect(nearestToErbil.id, 'erbil');

    // Coordinate near Halabja (~35.17, 45.98) should match Sulaymaniyah
    final nearestToSuly = LocationService.findNearestCity(35.17, 45.98, cities);
    expect(nearestToSuly.id, 'sulaymaniyah');

    // Coordinate near Zakho (~37.14, 42.68) should match Duhok
    final nearestToDuhok = LocationService.findNearestCity(37.14, 42.68, cities);
    expect(nearestToDuhok.id, 'duhok');
  });

  test('SettingsProvider manages useGPS flag correctly', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs);

    // Initial default is true
    expect(notifier.state.useGPS, isTrue);

    // Set useGPS to false
    await notifier.setUseGPS(false);
    expect(notifier.state.useGPS, isFalse);
    expect(prefs.getBool('useGPS'), isFalse);

    // Set useGPS back to true
    await notifier.setUseGPS(true);
    expect(notifier.state.useGPS, isTrue);
    expect(prefs.getBool('useGPS'), isTrue);
  });

  test('Daily calendar days calculate sequential, non-repeating indices', () {
    final epoch = DateTime(2024, 1, 1);
    final day1 = DateTime(2026, 9, 17);
    final day2 = DateTime(2026, 9, 18);
    final day8 = DateTime(2026, 9, 24);

    final idx1 = day1.difference(epoch).inDays;
    final idx2 = day2.difference(epoch).inDays;
    final idx8 = day8.difference(epoch).inDays;

    expect(idx2, idx1 + 1);
    // Crucial: 7 days later must NOT be the same index as day 1
    expect(idx8, isNot(idx1));
    expect(idx8, idx1 + 7);
  });

  test('Daily rotation logic correctly advances across calendar days and offsets', () {
    final sampleItems = List.generate(50, (i) => 'item_$i');
    final epoch = DateTime(2024, 1, 1);
    final day1 = DateTime(2026, 9, 17);
    final day2 = DateTime(2026, 9, 18);
    final day7 = DateTime(2026, 9, 24);

    final days1 = day1.difference(epoch).inDays;
    final days2 = day2.difference(epoch).inDays;
    final days7 = day7.difference(epoch).inDays;

    final index1 = days1 % sampleItems.length;
    final index2 = days2 % sampleItems.length;
    final index7 = days7 % sampleItems.length;

    expect(index2, (index1 + 1) % sampleItems.length);
    expect(index7, isNot(index1));

    // Test offset (tapping refresh/next)
    int offset = 0;
    expect((days1 + offset) % sampleItems.length, index1);
    offset++;
    expect((days1 + offset) % sampleItems.length, (index1 + 1) % sampleItems.length);
  });

  test('NotificationService safely handles platform checks without crashing', () async {
    // Calling safe methods on NotificationService must never throw LateInitializationError
    expect(() => NotificationService.isSupportedPlatform, returnsNormally);
    await expectLater(NotificationService.stopAdhan(), completes);
  });

  test('Check calculated times for Erbil and Sulaymaniyah on 2026-09-21 match official schedule', () {
    final erbilTimes = PrayerService.calculateTimes(
      latitude: 36.1912,
      longitude: 44.0119,
      method: 'KRG',
      asrMadhab: 'Shafi',
      offsets: const {},
      cityId: 'erbil',
      targetDate: DateTime(2026, 9, 21),
    );
    final sulyTimes = PrayerService.calculateTimes(
      latitude: 35.557,
      longitude: 45.4353,
      method: 'KRG',
      asrMadhab: 'Shafi',
      offsets: const {},
      cityId: 'sulaymaniyah',
      targetDate: DateTime(2026, 9, 21),
    );
    final duhokTimes = PrayerService.calculateTimes(
      latitude: 36.863,
      longitude: 42.95,
      method: 'KRG',
      asrMadhab: 'Shafi',
      offsets: const {},
      cityId: 'duhok',
      targetDate: DateTime(2026, 9, 21),
    );
    final kirkukTimes = PrayerService.calculateTimes(
      latitude: 35.4681,
      longitude: 44.3922,
      method: 'KRG',
      asrMadhab: 'Shafi',
      offsets: const {},
      cityId: 'kirkuk',
      targetDate: DateTime(2026, 9, 21),
    );
    // Erbil exact official times
    expect(erbilTimes['Fajr'], '04:25');
    expect(erbilTimes['Sunrise'], '05:57');
    expect(erbilTimes['Dhuhr'], '12:08');
    expect(erbilTimes['Asr'], '15:28');
    expect(erbilTimes['Maghrib'], '18:08');
    expect(erbilTimes['Isha'], '19:23');

    // Sulaymaniyah exact official times
    expect(sulyTimes['Fajr'], '04:25');
    expect(sulyTimes['Sunrise'], '05:46');
    expect(sulyTimes['Dhuhr'], '11:57');
    expect(sulyTimes['Asr'], '15:20');
    expect(sulyTimes['Maghrib'], '18:04');
    expect(sulyTimes['Isha'], '19:19');

    // Kirkuk exact official times
    expect(kirkukTimes['Fajr'], '04:24');
    expect(kirkukTimes['Sunrise'], '05:46');
    expect(kirkukTimes['Dhuhr'], '12:00');
    expect(kirkukTimes['Asr'], '15:26');
    expect(kirkukTimes['Maghrib'], '18:06');
    expect(kirkukTimes['Isha'], '19:21');

    // Duhok exact official times
    expect(duhokTimes['Fajr'], '04:29');
    expect(duhokTimes['Sunrise'], '05:58');
    expect(duhokTimes['Dhuhr'], '12:09');
    expect(duhokTimes['Asr'], '15:35');
    expect(duhokTimes['Maghrib'], '18:13');
    expect(duhokTimes['Isha'], '19:37');
  });

  test('Bookmark ID extraction parses surahId and ayahNum correctly', () {
    final bookmarkId = 'quran-2-255';
    int initialAyah = 1;
    final parts = bookmarkId.split('-');
    if (parts.length >= 3) {
      initialAyah = int.tryParse(parts.last) ?? 1;
    }
    expect(initialAyah, 255);

    // Fallback case with non-numeric or missing part
    final invalidId = 'quran-1';
    int fallbackAyah = 1;
    final invalidParts = invalidId.split('-');
    if (invalidParts.length >= 3) {
      fallbackAyah = int.tryParse(invalidParts.last) ?? 1;
    }
    expect(fallbackAyah, 1);
  });

  test('NotificationService init initializes timezone fallback without crashing', () async {
    await expectLater(NotificationService.init(), completes);
  });

  test('DataService provides correct Quran start pages and Juz ranges', () {
    // Al-Fatihah is on page 1
    expect(DataService.surahStartPages[1], 1);
    // Al-Baqarah is on page 2
    expect(DataService.surahStartPages[2], 2);
    // Ali 'Imran is on page 50
    expect(DataService.surahStartPages[3], 50);
    // An-Nas is on page 604
    expect(DataService.surahStartPages[114], 604);

    // Juz 1 is pages 1 to 21
    expect(DataService.juzPageRanges[1], [1, 21]);
    // Juz 30 is pages 582 to 604
    expect(DataService.juzPageRanges[30], [582, 604]);
    // Total 114 surahs have start pages
    expect(DataService.surahStartPages.length, 114);
    // Total 30 juz have page ranges
    expect(DataService.juzPageRanges.length, 30);
  });

  testWidgets('QuranPageDividerWidget renders page number and decorative cartouche', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuranPageDividerWidget(
            pageNumber: 15,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(QuranPageDividerWidget), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.byType(QuranPageDividerWidget));
    expect(tapped, isTrue);
  });

  testWidgets('SurahViewScreen renders and scrolls without RenderFlex overflow on narrow device', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'language': 'ku'});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: SurahViewScreen(
            surahId: 2,
            surahNameKu: 'بەقەرە',
            surahNameAr: 'البقرة',
            surahNameEn: 'Al-Baqarah',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SurahViewScreen), findsOneWidget);

    final listFinder = find.byType(ListView);
    if (listFinder.evaluate().isNotEmpty) {
      for (int i = 0; i < 15; i++) {
        await tester.drag(listFinder, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  });

  testWidgets('QuranScreen renders and scrolls without RenderFlex overflow', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'language': 'ku'});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: QuranScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(QuranScreen), findsOneWidget);

    final listFinder = find.byType(ListView);
    if (listFinder.evaluate().isNotEmpty) {
      for (int i = 0; i < 15; i++) {
        await tester.drag(listFinder.first, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  });

  testWidgets('OnboardingScreen presents Language selection as step 1', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify step 1 language options are displayed
    expect(find.text('کوردی'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // Tap Arabic option
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    // Verify language changed to Arabic in settings
    expect(find.text('الخطوة 1 من 4'), findsOneWidget);

    // Advance to next page
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    // Step 2 is now displayed in Arabic
    expect(find.text('مرحباً بك في تطبيق إسلام'), findsOneWidget);
  });

  testWidgets('SurahViewScreen immediately shows correct starting page without scrolling', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: SurahViewScreen(
            surahId: 18,
            surahNameAr: 'الكهف',
            surahNameEn: 'Al-Kahf',
            surahNameKu: 'کەهف',
          ),
        ),
      ),
    );

    // Verify on the very first frame without scrolling, page 293 is displayed in the AppBar
    expect(find.text('293'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  test('AladhanService correctly caches and retrieves official prayer times for international cities', () async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final cacheKey = 'prayer_official_v6_tokyo_$dateStr';

    SharedPreferences.setMockInitialValues({
      cacheKey: '{"Fajr":"04:25","Sunrise":"05:57","Dhuhr":"12:08","Asr":"15:28","Maghrib":"18:08","Isha":"19:23"}',
    });
    final prefs = await SharedPreferences.getInstance();

    final cached = AladhanService.getCachedTimes(
      cityId: 'tokyo',
      offsets: const {},
      prefs: prefs,
    );

    expect(cached, isNotNull);
    expect(cached!['Fajr'], '04:25');
    expect(cached['Dhuhr'], '12:08');
    expect(cached['Maghrib'], '18:08');
  });

  test('Official Kurdistan Ministry of Awqaf database loads and matches exact government timetable', () async {
    final db = await DataService.loadAwqafPrayerDatabase();
    expect(db, isNotEmpty);
    expect(db.containsKey('hawler'), isTrue);
    expect(db.containsKey('slemani'), isTrue);
    expect(db.containsKey('duhok'), isTrue);
    expect(db.containsKey('kirkuk'), isTrue);
    expect(db.containsKey('halabja'), isTrue);

    // Test Hawler (Erbil) for Sept 24th (09-24)
    final hawlerTimes = PrayerService.getOfficialAwqafTimes(
      cityId: 'erbil',
      targetDate: DateTime(2026, 9, 24),
    );
    expect(hawlerTimes, isNotNull);
    expect(hawlerTimes!['Fajr'], '04:28');
    expect(hawlerTimes['Sunrise'], '05:59');
    expect(hawlerTimes['Dhuhr'], '12:07');
    expect(hawlerTimes['Asr'], '15:25');
    expect(hawlerTimes['Maghrib'], '18:04');
    expect(hawlerTimes['Isha'], '19:19');

    // Test Slemani (Sulaymaniyah) for Sept 24th (09-24)
    final slemaniTimes = PrayerService.getOfficialAwqafTimes(
      cityId: 'sulaymaniyah',
      targetDate: DateTime(2026, 9, 24),
    );
    expect(slemaniTimes, isNotNull);
    expect(slemaniTimes!['Fajr'], '04:28');
    expect(slemaniTimes['Sunrise'], '05:48');
    expect(slemaniTimes['Dhuhr'], '11:56');
    expect(slemaniTimes['Asr'], '15:17');
    expect(slemaniTimes['Maghrib'], '18:00');
    expect(slemaniTimes['Isha'], '19:15');

    // Verify PrayerService.calculateTimes strictly uses Awqaf database without astronomical drift
    final calculated = PrayerService.calculateTimes(
      latitude: 36.1912,
      longitude: 44.0119,
      method: 'KRG',
      asrMadhab: 'Shafi',
      offsets: const {},
      cityId: 'erbil',
      targetDate: DateTime(2026, 9, 24),
    );
    expect(calculated['Fajr'], '04:28');
    expect(calculated['Dhuhr'], '12:07');
    expect(calculated['Maghrib'], '18:04');

    // Verify user offsets work on top of official Awqaf times
    final offsetHawler = PrayerService.getOfficialAwqafTimes(
      cityId: 'erbil',
      targetDate: DateTime(2026, 9, 24),
      offsets: {'Fajr': 2, 'Maghrib': -1},
    );
    expect(offsetHawler!['Fajr'], '04:30'); // 04:28 + 2 mins
    expect(offsetHawler['Maghrib'], '18:03'); // 18:04 - 1 min
  });

  test('ActivityProvider resets broken streak to 0 on load when user was inactive', () async {
    SharedPreferences.setMockInitialValues({
      'streak': 15,
      'activityLog': '{"2025-01-01": 5}', // Ancient log
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = ActivityNotifier(prefs);

    expect(notifier.state.streak, 0);
  });

  test('ActivityNotifier calculateWorshipStreak handles consecutive days, missed days, and active streaks', () {
    final now = DateTime(2026, 10, 24);

    // 1. Single day today
    expect(ActivityNotifier.calculateWorshipStreak({'2026-10-24'}, now), 1);

    // 2. Yesterday completed, today in progress (streak kept alive)
    expect(ActivityNotifier.calculateWorshipStreak({'2026-10-23'}, now), 1);

    // 3. Consecutive days (yesterday + today)
    expect(ActivityNotifier.calculateWorshipStreak({'2026-10-23', '2026-10-24'}, now), 2);

    // 4. Multi-day run (5 days)
    expect(
      ActivityNotifier.calculateWorshipStreak({
        '2026-10-20',
        '2026-10-21',
        '2026-10-22',
        '2026-10-23',
        '2026-10-24',
      }, now),
      5,
    );

    // 5. Missed yesterday & today -> broken streak
    expect(ActivityNotifier.calculateWorshipStreak({'2026-10-22'}, now), 0);
  });

  test('ActivityNotifier recordWorshipCompletion updates streak, awards badges, and handles toggling', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = ActivityNotifier(prefs);

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Complete worship today
    final streak = await notifier.recordWorshipCompletion(isCompleted: true);
    expect(streak, 1);
    expect(notifier.state.streak, 1);
    expect(notifier.state.completedWorshipDays.contains(todayStr), true);
    expect(notifier.state.badges.any((b) => b.nameEn == 'Worship Devotee'), true);

    // Uncheck worship today
    final revertedStreak = await notifier.recordWorshipCompletion(isCompleted: false);
    expect(revertedStreak, 0);
    expect(notifier.state.streak, 0);
    expect(notifier.state.completedWorshipDays.contains(todayStr), false);
  });

  test('SettingsProvider safely populates missing keys in prayer offsets and notifications', () async {
    SharedPreferences.setMockInitialValues({
      'prayerOffsets': '{"Fajr": 3}', // Missing all other prayers
      'prayerNotifications': '{"Fajr": false}', // Missing other prayers
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    final settings = container.read(settingsProvider);
    expect(settings.prayerOffsets['Fajr'], 3);
    expect(settings.prayerOffsets['Dhuhr'], 0);
    expect(settings.prayerOffsets['Asr'], 0);
    expect(settings.prayerNotifications['Fajr'], false);
    expect(settings.prayerNotifications['Dhuhr'], true);
    expect(settings.prayerNotifications['Isha'], true);
  });

  test('QuranAudioHandler updatePlaybackStatus updates MediaItem duration and PlaybackState position', () {
    final handler = QuranAudioHandler();
    handler.setQuranMediaItem(
      id: '11_10',
      title: 'هود (ئایەتی 10)',
      artist: 'یاسر الدوسری',
    );

    // Initial item has no duration
    expect(handler.mediaItem.value?.title, 'هود (ئایەتی 10)');
    expect(handler.mediaItem.value?.duration, isNull);

    // Update with duration from audio player
    handler.updatePlaybackStatus(
      isPlaying: true,
      position: const Duration(seconds: 5),
      duration: const Duration(seconds: 25),
    );

    expect(handler.mediaItem.value?.duration, const Duration(seconds: 25));
    expect(handler.playbackState.value.playing, true);
    expect(handler.playbackState.value.updatePosition, const Duration(seconds: 5));
    expect(handler.playbackState.value.bufferedPosition, const Duration(seconds: 5));

    // When paused, state must stay ready so lock screen controls don't disappear
    handler.updatePlaybackStatus(
      isPlaying: false,
      position: const Duration(seconds: 10),
      duration: const Duration(seconds: 25),
    );
    expect(handler.playbackState.value.playing, false);
    expect(handler.playbackState.value.processingState, AudioProcessingState.ready);

    // When explicitly stopped, state becomes idle
    handler.updatePlaybackStatus(
      isPlaying: false,
      position: Duration.zero,
      isStopped: true,
    );
    expect(handler.playbackState.value.playing, false);
    expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
  });

  test('10-day prayer notification IDs generate 50 unique non-overlapping IDs from 1 to 50', () {
    final ids = <int>{};
    for (int dayOffset = 0; dayOffset < 10; dayOffset++) {
      for (int pIndex = 1; pIndex <= 5; pIndex++) {
        final notifId = dayOffset * 5 + pIndex;
        expect(ids.contains(notifId), isFalse, reason: 'Collision on notifId $notifId');
        ids.add(notifId);
        expect(notifId >= 1 && notifId <= 50, isTrue);
      }
    }
    expect(ids.length, 50);
    // Ensure no clash with adhkar (501..504), quran (9999), or test (9998)
    for (final id in ids) {
      expect(id < 501, isTrue);
    }
  });

  test('All Adhan and Fajr audio files exist in both assets and android raw resources', () {
    final allVoices = {
      ...NotificationService.adhanVoiceNames.keys,
      ...NotificationService.fajrAdhanVoiceNames.keys,
    };
    for (final voice in allVoices) {
      final assetFile = File('assets/audio/adhan/$voice.mp3');
      final rawFile = File('android/app/src/main/res/raw/$voice.mp3');
      expect(assetFile.existsSync(), isTrue, reason: 'Missing asset: $voice.mp3');
      expect(rawFile.existsSync(), isTrue, reason: 'Missing res/raw: $voice.mp3');
    }
  });

  test('Adhan notification payload correctly embeds prayer and voice', () {
    final payloadFajr = 'prayer_adhan:Fajr:mishary_fajr';
    final partsFajr = payloadFajr.split(':');
    expect(partsFajr.length, 3);
    expect(partsFajr[0], 'prayer_adhan');
    expect(partsFajr[1], 'Fajr');
    expect(partsFajr[2], 'mishary_fajr');

    final payloadDhuhr = 'prayer_adhan:Dhuhr:nasser';
    final partsDhuhr = payloadDhuhr.split(':');
    expect(partsDhuhr[0], 'prayer_adhan');
    expect(partsDhuhr[1], 'Dhuhr');
    expect(partsDhuhr[2], 'nasser');
  });

  test('Timezone database contains Kurdistan Asia/Baghdad timezone', () {
    tz.initializeTimeZones();
    final baghdad = tz.getLocation('Asia/Baghdad');
    expect(baghdad.name, 'Asia/Baghdad');
  });

  test('Worldwide cities database contains 350+ cities with complete metadata and worldwide country coverage', () async {
    final file = File('assets/data/cities.json');
    expect(file.existsSync(), isTrue);
    final jsonStr = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    expect(jsonList.length, greaterThanOrEqualTo(350));

    final cities = jsonList.map((j) => City.fromJson(j)).toList();
    final cityIds = cities.map((c) => c.id).toSet();
    final countries = cities.map((c) => c.country).toSet();

    // Ensure coverage of over 180 countries
    expect(countries.length, greaterThanOrEqualTo(180));

    // Check Kurdish core
    expect(cityIds.contains('erbil'), isTrue);
    expect(cityIds.contains('sulaymaniyah'), isTrue);
    expect(cityIds.contains('duhok'), isTrue);
    expect(cityIds.contains('kirkuk'), isTrue);
    expect(cityIds.contains('halabja'), isTrue);
    expect(cityIds.contains('koya'), isTrue);
    expect(cityIds.contains('chamchamal'), isTrue);

    // Check Holy cities & Gulf
    expect(cityIds.contains('makkah'), isTrue);
    expect(cityIds.contains('madinah'), isTrue);
    expect(cityIds.contains('dubai'), isTrue);
    expect(cityIds.contains('doha'), isTrue);

    // Check Diaspora / Worldwide across all continents
    expect(cityIds.contains('berlin'), isTrue);
    expect(cityIds.contains('london'), isTrue);
    expect(cityIds.contains('stockholm'), isTrue);
    expect(cityIds.contains('washington-dc'), isTrue);
    expect(cityIds.contains('istanbul'), isTrue);
    expect(cityIds.contains('tehran'), isTrue);
    expect(cityIds.contains('tokyo'), isTrue);
    expect(cityIds.contains('cairo'), isTrue);
    expect(cityIds.contains('ottawa'), isTrue);
    expect(cityIds.contains('canberra'), isTrue);
    expect(cityIds.contains('brasilia'), isTrue);

    for (final city in cities) {
      expect(city.id.isNotEmpty, isTrue);
      expect(city.ku.isNotEmpty, isTrue);
      expect(city.ar.isNotEmpty, isTrue);
      expect(city.en.isNotEmpty, isTrue);
      expect(city.country.isNotEmpty, isTrue);
      expect(city.countryKu.isNotEmpty, isTrue);
      expect(city.lat, inInclusiveRange(-90.0, 90.0));
      expect(city.lng, inInclusiveRange(-180.0, 180.0));
    }
  });

  test('DataService loads pray steps with English and Arabic substeps', () async {
    final steps = await DataService.loadPraySteps();
    expect(steps.isNotEmpty, isTrue);
    final wudu = steps.firstWhere((s) => s['id'] == 1);
    expect(wudu['title_en'], 'Wudu (Ablution)');
    expect(wudu['substeps_en'], isNotNull);
    final substepsEn = wudu['substeps_en'] as List;
    expect(substepsEn.length, 12);
    expect(substepsEn.first, contains('Make the sincere intention'));
    
    expect(wudu['substeps_ar'], isNotNull);
    final substepsAr = wudu['substeps_ar'] as List;
    expect(substepsAr.length, 12);
    expect(substepsAr.first, contains('النية بالقلب'));
  });
}







