import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adhan_playing_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/activity_provider.dart';
import '../services/prayer_service.dart';
import '../services/aladhan_service.dart';
import '../services/data_service.dart';
import '../services/hadith_book_service.dart';
import '../main.dart';
import 'search_screen.dart';
import 'adhan_settings_screen.dart';
import 'tasbih_screen.dart';
import 'khatam_tracker_screen.dart';
import 'zakat_screen.dart';
import 'situations_screen.dart';
import 'topics_screen.dart';
import 'qibla_screen.dart';
import 'kids_stories_screen.dart';
import 'how_to_pray_screen.dart';
import 'utilities_screen.dart';
import 'surah_view_screen.dart';
import 'hadith_adhkar_screen.dart';
import 'world_prayer_times_screen.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../services/location_service.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/city_selector_sheet.dart';
import '../models/city.dart';
import 'package:flutter/services.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  String _lastScheduledSignature = '';
  String _lastActiveDayKey = '';
  int _verseOffset = 0;
  int _hadithOffset = 0;
  int _sunnahOffset = 0;

  List<dynamic> _cachedVerses = [];
  List<dynamic> _cachedSunnahs = [];
  Map<String, dynamic>? _dailyVerse;
  Map<String, dynamic>? _todayHadith;
  Map<String, dynamic>? _todaySunnah;
  Map<String, dynamic>? _todayQA;
  Map<String, dynamic>? _upcomingEvent;

  bool _isQaExpanded = false;

  Map<String, bool> _habits = {
    'fajr': false,
    'dhuhr': false,
    'asr': false,
    'maghrib': false,
    'isha': false,
    'adhkar': false,
    'quran': false,
  };

  Timer? _prayerCheckTimer;
  String? _lastAlertedPrayerSignature;
  Map<String, String>? _cachedPrayerTimes;
  String? _lastPrayerCalculationSignature;
  String _lastWidgetUpdateSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _lastActiveDayKey = '${now.year}-${now.month}-${now.day}';
    _loadDashboardContent();
    _loadHabits();
    _prayerCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkForegroundPrayerAlert();
      _checkDayChange();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDetectGpsLocation();
      _fetchOfficialPrayerTimes();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prayerCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDayChange();
      _autoDetectGpsLocation();
      _fetchOfficialPrayerTimes();
    }
  }

  Future<void> _autoDetectGpsLocation() async {
    if (!mounted) return;
    try {
      final settings = ref.read(settingsProvider);
      if (!settings.useGPS) return;

      var cities = ref.read(citiesFutureProvider).value;
      if (cities == null || cities.isEmpty) {
        cities = await ref.read(citiesFutureProvider.future);
      }
      if (cities == null || cities.isEmpty || !mounted) return;

      final nearest = await LocationService.detectNearestCity(cities);
      if (nearest != null && mounted) {
        if (nearest.id != settings.userCityId) {
          debugPrint('[GPS] Auto-detected new nearest city: ${nearest.ku} (${nearest.id})');
          await ref.read(settingsProvider.notifier).setUserCityId(nearest.id);
          _fetchOfficialPrayerTimes();
        }
      }
    } catch (e) {
      debugPrint('[GPS] Auto-detection error: $e');
    }
  }

  void _checkDayChange() {
    if (!mounted) return;
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (_lastActiveDayKey.isNotEmpty && _lastActiveDayKey != todayKey) {
      _lastActiveDayKey = todayKey;
      _verseOffset = 0;
      _hadithOffset = 0;
      _sunnahOffset = 0;
      _cachedPrayerTimes = null;
      _lastPrayerCalculationSignature = null;
      _loadDashboardContent();
      _loadHabits();
      _fetchOfficialPrayerTimes();
      setState(() {});
    }
  }

  Future<void> _fetchOfficialPrayerTimes() async {
    if (!mounted) return;
    try {
      final settings = ref.read(settingsProvider);
      final cities = ref.read(citiesFutureProvider).value;
      if (cities == null || cities.isEmpty) return;

      final activeCity = cities.firstWhere(
        (c) => c.id == settings.userCityId,
        orElse: () => cities.first,
      );

      final official = PrayerService.getOfficialAwqafTimes(
        cityId: activeCity.id,
        offsets: settings.prayerOffsets,
      );
      final fetched = official ?? await AladhanService.fetchTimes(
        latitude: activeCity.lat,
        longitude: activeCity.lng,
        method: settings.calculationMethod,
        asrMadhab: settings.asrMadhab,
        offsets: settings.prayerOffsets,
        cityId: activeCity.id,
        countryCode: activeCity.country,
      );

      if (mounted) {
        final now = DateTime.now();
        final sig = '${now.year}-${now.month}-${now.day}_${activeCity.id}_${settings.calculationMethod}_${settings.asrMadhab}_${settings.prayerOffsets}';
        setState(() {
          _cachedPrayerTimes = fetched;
          _lastPrayerCalculationSignature = sig;
        });

        final cityName = settings.language == 'ku'
            ? activeCity.ku
            : (settings.language == 'ar' ? activeCity.ar : activeCity.en);
        final nextPrayer = PrayerService.getNextPrayer(fetched);
        _updateWidgetIfChanged(
          cityName: cityName,
          times: fetched,
          nextPrayer: nextPrayer,
        );

        NotificationService.scheduleDailyPrayers(
          prayerTimes: fetched,
          enabledPrayers: settings.prayerNotifications,
          language: settings.language,
          soundType: settings.notificationSound,
          adhanVoice: settings.selectedAdhanVoice,
          fajrAdhanVoice: settings.selectedFajrAdhanVoice,
          latitude: activeCity.lat,
          longitude: activeCity.lng,
          method: settings.calculationMethod,
          asrMadhab: settings.asrMadhab,
          offsets: settings.prayerOffsets,
          cityId: activeCity.id,
          countryCode: activeCity.country,
        );
      }
    } catch (_) {}
  }

  void _updateWidgetIfChanged({
    required String cityName,
    required Map<String, String> times,
    required Map<String, String> nextPrayer,
  }) {
    final now = DateTime.now();
    final lang = ref.read(settingsProvider).language;
    final sig = '${now.hour}:${now.minute}_${cityName}_${nextPrayer['name']}_${nextPrayer['time']}_$lang';
    if (_lastWidgetUpdateSignature != sig) {
      _lastWidgetUpdateSignature = sig;
      WidgetService.updatePrayerWidget(
        cityName: cityName,
        prayerTimes: times,
        nextPrayerInfo: nextPrayer,
        language: lang,
      );
    }
  }

  void _checkForegroundPrayerAlert() {
    if (!mounted) return;
    try {
      final settings = ref.read(settingsProvider);

      final cities = ref.read(citiesFutureProvider).value;
      if (cities == null || cities.isEmpty) return;

      final activeCity = cities.firstWhere(
        (c) => c.id == settings.userCityId,
        orElse: () => cities.first,
      );

      final now = DateTime.now();
      final sig = '${now.year}-${now.month}-${now.day}_${activeCity.id}_${settings.calculationMethod}_${settings.asrMadhab}_${settings.prayerOffsets}';
      if (_lastPrayerCalculationSignature != sig || _cachedPrayerTimes == null) {
        final official = PrayerService.getOfficialAwqafTimes(
          cityId: activeCity.id,
          offsets: settings.prayerOffsets,
        );
        final prefs = ref.read(sharedPreferencesProvider);
        final cached = AladhanService.getCachedTimes(
          cityId: activeCity.id,
          offsets: settings.prayerOffsets,
          prefs: prefs,
          countryCode: activeCity.country,
        );
        _cachedPrayerTimes = official ?? cached ?? PrayerService.calculateTimes(
          latitude: activeCity.lat,
          longitude: activeCity.lng,
          method: settings.calculationMethod,
          asrMadhab: settings.asrMadhab,
          offsets: settings.prayerOffsets,
          cityId: activeCity.id,
          countryCode: activeCity.country,
        );
        _lastPrayerCalculationSignature = sig;
      }
      final times = _cachedPrayerTimes!;

      final cityName = settings.language == 'ku'
          ? activeCity.ku
          : (settings.language == 'ar' ? activeCity.ar : activeCity.en);
      final nextPrayer = PrayerService.getNextPrayer(times);
      _updateWidgetIfChanged(
        cityName: cityName,
        times: times,
        nextPrayer: nextPrayer,
      );

      if (settings.notificationSound != 'adhan') return;

      for (final entry in times.entries) {
        final pName = entry.key;
        if (pName == 'Sunrise') continue;
        if (settings.prayerNotifications[pName] == false) continue;

        final parts = entry.value.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;

        if (now.hour == h && now.minute == m) {
          final sig = '${now.year}-${now.month}-${now.day}_$pName';
          if (_lastAlertedPrayerSignature != sig) {
            _lastAlertedPrayerSignature = sig;
            final voice = pName == 'Fajr' ? 'mishary_fajr' : settings.selectedAdhanVoice;
            AdhanPlayingDialog.show(
              context,
              prayerName: pName,
              voiceId: voice,
              language: settings.language,
              autoPlayAudio: false,
            );
          }
          break;
        }
      }
    } catch (_) {}
  }

  String? _lastLoadedHabitDate;

  bool _isWorshipCompleted(Map<String, bool> habits) {
    if (habits.isEmpty) return false;
    final allDone = habits.values.every((v) => v);
    final prayersAndAdhkarDone = (habits['fajr'] ?? false) &&
        (habits['dhuhr'] ?? false) &&
        (habits['asr'] ?? false) &&
        (habits['maghrib'] ?? false) &&
        (habits['isha'] ?? false) &&
        (habits['adhkar'] ?? false);
    return allDone || prayersAndAdhkarDone;
  }

  Future<void> _loadHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      _lastLoadedHabitDate = today;
      final raw = prefs.getString('daily_habits_$today');
      if (raw != null) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        if (mounted) {
          setState(() {
            decoded.forEach((k, v) {
              if (_habits.containsKey(k)) {
                _habits[k] = v as bool;
              }
            });
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _habits.updateAll((k, v) => false);
          });
        }
      }

      final isCompleted = _isWorshipCompleted(_habits);
      final activityState = ref.read(activityProvider);
      if (isCompleted && !activityState.completedWorshipDays.contains(today)) {
        await ref.read(activityProvider.notifier).recordWorshipCompletion(isCompleted: true);
      }
    } catch (_) {}
  }

  Future<void> _toggleHabit(String key, bool val) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    // If the date has changed (e.g. user left app open overnight), reset habits
    if (_lastLoadedHabitDate != null && _lastLoadedHabitDate != today) {
      setState(() {
        _habits.updateAll((k, v) => false);
        _lastLoadedHabitDate = today;
      });
    }

    final bool wasCompleted = _isWorshipCompleted(_habits);

    setState(() {
      _habits[key] = val;
    });

    final bool isNowCompleted = _isWorshipCompleted(_habits);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('daily_habits_$today', jsonEncode(_habits));
    } catch (_) {}

    if (isNowCompleted != wasCompleted) {
      final newStreak = await ref.read(activityProvider.notifier).recordWorshipCompletion(
        isCompleted: isNowCompleted,
      );

      if (isNowCompleted && mounted) {
        HapticFeedback.heavyImpact();
        _showStreakCelebration(newStreak);
      }
    }
  }

  void _showStreakCelebration(int streak) {
    final settings = ref.read(settingsProvider);
    final isKu = settings.language == 'ku';
    final isAr = settings.language == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.local_fire_department_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isKu
                    ? 'ماشاءالله! هەموو پەرستشەکانی ئەمڕۆت بەجێهێنا'
                    : isAr
                        ? 'ما شاء الله! أتممت جميع عبادات اليوم'
                        : 'Masha\'Allah! All Daily Worships Completed',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Rabar',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      isKu
                          ? '$streak ڕۆژ بەردەوامی (ستریک)'
                          : isAr
                              ? '$streak أيام مواظبة (ستريك)'
                              : '$streak Days Streak',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Rabar',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isKu
                    ? '«أَحَبُّ الأَعْمَالِ إِلَى اللهِ أَدْوَمُهَا وَإِنْ قَلَّ»\nخۆشەویستترین کردەوە لای خودا بەردەوامترینیانە با کەمیش بێت.'
                    : isAr
                        ? '«أَحَبُّ الأَعْمَالِ إِلَى اللهِ أَدْوَمُهَا وَإِنْ قَلَّ»\nثبّتك الله وبارك في همتك وطاعتك.'
                        : '«The most beloved of deeds to Allah are those that are most consistent, even if they are few.»',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'Rabar',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isKu ? 'دەستت خۆش' : isAr ? 'الحمد لله' : 'Alhamdulillah',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreakPill(int streak, bool isTodayCompleted, String lang) {
    final bool hasStreak = streak > 0;
    final color = hasStreak ? Colors.orangeAccent : Colors.white38;
    final bgColor = hasStreak
        ? (isTodayCompleted ? Colors.orange.withOpacity(0.22) : Colors.orange.withOpacity(0.12))
        : Colors.white.withOpacity(0.05);
    final borderColor = hasStreak
        ? (isTodayCompleted ? Colors.orangeAccent : Colors.orangeAccent.withOpacity(0.35))
        : Colors.white12;

    final String text = lang == 'ku'
        ? '$streak ڕۆژ'
        : lang == 'ar'
            ? '$streak يوم'
            : '$streak days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: hasStreak && isTodayCompleted
            ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Rabar',
            ),
          ),
        ],
      ),
    );
  }

  String _getHabitSubtitle(String lang, bool isCompleted, int count) {
    if (isCompleted) {
      if (lang == 'ku') return 'ماشاءالله! هەموو پەرستشەکانت بەجێهێنا';
      if (lang == 'ar') return 'ما شاء الله! أتممت جميع العبادات';
      return 'Masha\'Allah! All worships completed';
    }
    if (lang == 'ku') {
      if (count == 6 && !(_habits['quran'] ?? false)) {
        return '٦ لە ٧ پەرستش • تەنها قورئان ماوە بۆ ١٠٠٪';
      }
      return '$count لە ٧ پەرستش ئەنجامدراون';
    }
    if (lang == 'ar') {
      if (count == 6 && !(_habits['quran'] ?? false)) {
        return '٦ من ٧ عبادات • بقي القرآن فقط لاكتمال المواظبة';
      }
      return 'تم إكمال $count من ٧ عبادات';
    }
    if (count == 6 && !(_habits['quran'] ?? false)) {
      return '6 of 7 completed • Only Quran remains for 100%';
    }
    return '$count of 7 worships completed';
  }

  Future<void> _loadDashboardContent() async {
    try {
      final now = DateTime.now();
      final daysSinceEpoch = DateTime(now.year, now.month, now.day).difference(DateTime(2024, 1, 1)).inDays;

      // 1. Daily Verse (From 50+ curated inspiring Quranic verses)
      if (_cachedVerses.isEmpty) {
        _cachedVerses = await DataService.loadDailyVerses();
      }
      if (_cachedVerses.isNotEmpty) {
        final rawIndex = (daysSinceEpoch + _verseOffset) % _cachedVerses.length;
        final verseIndex = rawIndex < 0 ? (rawIndex + _cachedVerses.length) : rawIndex;
        _dailyVerse = Map<String, dynamic>.from(_cachedVerses[verseIndex] as Map);
      }

      // 2. Hadith of the Day (Advances deterministically every calendar day)
      final hadithResult = await HadithBookService.getHadithOfTheDay(dayOffset: _hadithOffset);
      if (hadithResult != null) {
        _todayHadith = hadithResult;
      }

      // 3. Sunnah of the Day (Advances deterministically across all 45+ sunnahs)
      if (_cachedSunnahs.isEmpty) {
        _cachedSunnahs = await DataService.loadSunnahs();
      }
      if (_cachedSunnahs.isNotEmpty) {
        final rawIndex = (daysSinceEpoch + _sunnahOffset) % _cachedSunnahs.length;
        final sunnahIndex = rawIndex < 0 ? (rawIndex + _cachedSunnahs.length) : rawIndex;
        _todaySunnah = Map<String, dynamic>.from(_cachedSunnahs[sunnahIndex] as Map);
      }

      // 4. Q&A of the Day
      final qas = await DataService.loadQA();
      if (qas.isNotEmpty) {
        final rawQaIndex = daysSinceEpoch % qas.length;
        final qaIndex = rawQaIndex < 0 ? (rawQaIndex + qas.length) : rawQaIndex;
        _todayQA = qas[qaIndex];
      }

      // 5. Upcoming Event check
      final events = await DataService.loadEvents();
      _upcomingEvent = _checkUpcomingEvent(events, now);

      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _nextVerse() {
    if (_cachedVerses.isEmpty) return;
    setState(() {
      _verseOffset++;
      final now = DateTime.now();
      final daysSinceEpoch = DateTime(now.year, now.month, now.day).difference(DateTime(2024, 1, 1)).inDays;
      final rawIndex = (daysSinceEpoch + _verseOffset) % _cachedVerses.length;
      final verseIndex = rawIndex < 0 ? (rawIndex + _cachedVerses.length) : rawIndex;
      _dailyVerse = Map<String, dynamic>.from(_cachedVerses[verseIndex] as Map);
    });
  }

  void _nextHadith() async {
    _hadithOffset++;
    final hadithResult = await HadithBookService.getHadithOfTheDay(dayOffset: _hadithOffset);
    if (hadithResult != null && mounted) {
      setState(() {
        _todayHadith = hadithResult;
      });
    }
  }

  void _nextSunnah() {
    if (_cachedSunnahs.isEmpty) return;
    setState(() {
      _sunnahOffset++;
      final now = DateTime.now();
      final daysSinceEpoch = DateTime(now.year, now.month, now.day).difference(DateTime(2024, 1, 1)).inDays;
      final rawIndex = (daysSinceEpoch + _sunnahOffset) % _cachedSunnahs.length;
      final sunnahIndex = rawIndex < 0 ? (rawIndex + _cachedSunnahs.length) : rawIndex;
      _todaySunnah = Map<String, dynamic>.from(_cachedSunnahs[sunnahIndex] as Map);
    });
  }

  Map<String, dynamic>? _checkUpcomingEvent(List<dynamic> events, DateTime now) {
    for (final e in events) {
      final dateStr = e['date']?.toString() ?? '';
      try {
        final evDate = DateTime.parse(dateStr);
        final difference = evDate.difference(DateTime(now.year, now.month, now.day)).inDays;
        if (difference >= 0 && difference <= 30) {
          return {
            ...e as Map<String, dynamic>,
            'daysRemaining': difference,
          };
        }
      } catch (_) {}
    }
    return null;
  }

  double _calculateHabitProgress() {
    if (_habits.isEmpty) return 0.0;
    final completed = _habits.values.where((v) => v).length;
    return completed / _habits.length;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final activity = ref.watch(activityProvider);
    final theme = settings.palette;
    final citiesAsync = ref.watch(citiesFutureProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';
    final langKey = settings.language == 'ar' ? 'ar' : settings.language == 'en' ? 'en' : 'ku';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: citiesAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
          error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: Colors.white))),
          data: (cities) {
            final activeCity = cities.firstWhere(
              (c) => c.id == settings.userCityId,
              orElse: () => cities.first,
            );

            final prefs = ref.watch(sharedPreferencesProvider);
            final officialAwqaf = PrayerService.getOfficialAwqafTimes(
              cityId: activeCity.id,
              offsets: settings.prayerOffsets,
            );
            final cachedOfficial = AladhanService.getCachedTimes(
              cityId: activeCity.id,
              offsets: settings.prayerOffsets,
              prefs: prefs,
              countryCode: activeCity.country,
            );

            final now = DateTime.now();
            final currentSig = '${now.year}-${now.month}-${now.day}_${activeCity.id}_${settings.calculationMethod}_${settings.asrMadhab}_${settings.prayerOffsets}';
            final isCachedForCurrentCity = _lastPrayerCalculationSignature == currentSig && _cachedPrayerTimes != null;

            final times = officialAwqaf ??
                (isCachedForCurrentCity ? _cachedPrayerTimes : null) ??
                cachedOfficial ??
                PrayerService.calculateTimes(
                  latitude: activeCity.lat,
                  longitude: activeCity.lng,
                  method: settings.calculationMethod,
                  asrMadhab: settings.asrMadhab,
                  offsets: settings.prayerOffsets,
                  cityId: activeCity.id,
                  countryCode: activeCity.country,
                );

            final todayDate = '${now.year}-${now.month}-${now.day}';
            final scheduleSignature =
                '${todayDate}_${activeCity.id}_${settings.calculationMethod}_${settings.notificationSound}_${settings.selectedAdhanVoice}_${settings.selectedFajrAdhanVoice}_${settings.prayerNotifications}_${settings.prayerOffsets}';
            if (_lastScheduledSignature != scheduleSignature) {
              _lastScheduledSignature = scheduleSignature;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchOfficialPrayerTimes();
              });
            }

            final nextPrayer = PrayerService.getNextPrayer(times);
            final cityName = settings.language == 'ku'
                ? activeCity.ku
                : (settings.language == 'ar' ? activeCity.ar : activeCity.en);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateWidgetIfChanged(
                cityName: cityName,
                times: times,
                nextPrayer: nextPrayer,
              );
            });

            final prayerIcons = <String, IconData>{
              'Fajr': Icons.wb_twilight_rounded,
              'Sunrise': Icons.wb_sunny_rounded,
              'Dhuhr': Icons.light_mode_rounded,
              'Asr': Icons.cloud_queue_rounded,
              'Maghrib': Icons.nightlight_round,
              'Isha': Icons.bedtime_rounded,
            };

            final prayerLocalized = {
              'Fajr': {'ku': 'بەیانی', 'ar': 'الفجر', 'en': 'Fajr'},
              'Sunrise': {'ku': 'ڕۆژهەڵات', 'ar': 'الشروق', 'en': 'Sunrise'},
              'Dhuhr': {'ku': 'نیوەڕۆ', 'ar': 'الظهر', 'en': 'Dhuhr'},
              'Asr': {'ku': 'عەسڕ', 'ar': 'العصر', 'en': 'Asr'},
              'Maghrib': {'ku': 'مەغریب', 'ar': 'المغرب', 'en': 'Maghrib'},
              'Isha': {'ku': 'عیشا', 'ar': 'العشاء', 'en': 'Isha'},
            };

            final progressVal = _calculateHabitProgress();
            final isWorshipCompletedToday = _isWorshipCompleted(_habits);
            final completedHabitsCount = _habits.values.where((v) => v).length;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top App Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'بِسمِ اللَّهِ الرَّحمٰنِ الرَّحيمِ',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                settings.language == 'ku'
                                    ? 'پەڕەی سەرەکی'
                                    : settings.language == 'ar'
                                        ? 'الرئيسية'
                                        : 'Dashboard',
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Rabar',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            BouncingButton(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BouncingButton(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AdhanSettingsScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Icon(Icons.notifications_active_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // CITY PICKER & HIJRI DATE CARD
                    BouncingButton(
                      onTap: () => _showCitySelector(context, ref, cities, activeCity.id, settings.language),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.cardColor, theme.backgroundColor.withOpacity(0.9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_rounded, color: Theme.of(context).colorScheme.primary, size: 19),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          settings.language == 'ku'
                                              ? activeCity.ku
                                              : settings.language == 'ar'
                                                  ? activeCity.ar
                                                  : activeCity.en,
                                          style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (settings.useGPS) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4), width: 0.8),
                                          ),
                                          child: Text(
                                            'GPS',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatHijriDate(
                                      now.add(Duration(days: settings.hijriAdjustment)),
                                      settings.language,
                                    ),
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5, fontFamily: 'Rabar'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BouncingButton(
                                  onTap: () async {
                                    final nearest = await LocationService.detectNearestCity(cities);
                                    if (nearest != null) {
                                      await ref.read(settingsProvider.notifier).setUserCityId(nearest.id);
                                      await ref.read(settingsProvider.notifier).setUseGPS(true);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              settings.language == 'ku'
                                                  ? 'شاری نزیکت دیاریکرا: ${nearest.ku}'
                                                  : settings.language == 'ar'
                                                      ? 'تم تحديد المدينة: ${nearest.ar}'
                                                      : 'Detected city: ${nearest.en}',
                                            ),
                                            backgroundColor: Theme.of(context).colorScheme.primary,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              settings.language == 'ku'
                                                  ? 'تکایە شوێن (GPS) لە مۆبایلەکەت کارا بکە'
                                                  : 'Please enable Location (GPS) on your phone',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.my_location_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.35)),
                                  ),
                                  child: Text(
                                    settings.language == 'ku' ? 'گۆڕین' : settings.language == 'ar' ? 'تغيير' : 'Change',
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Upcoming Event Banner
                    if (_upcomingEvent != null) ...[
                      _buildUpcomingEventBanner(settings.language),
                      const SizedBox(height: 16),
                    ],

                    // NEXT PRAYER COUNTDOWN CARD
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.cardColor,
                            theme.cardColor.withOpacity(0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.55), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        settings.language == 'ar'
                                            ? 'الصلاة القادمة: ${prayerLocalized[nextPrayer['name']]?['ar'] ?? nextPrayer['name']}'
                                            : (settings.language == 'en'
                                                ? 'Next Prayer: ${prayerLocalized[nextPrayer['name']]?['en'] ?? nextPrayer['name']}'
                                                : 'نوێژی داهاتوو: ${prayerLocalized[nextPrayer['name']]?['ku'] ?? nextPrayer['name']}'),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontFamily: 'Rabar',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  settings.language == 'ar'
                                      ? 'الساعة ${nextPrayer['time']}'
                                      : (settings.language == 'en'
                                          ? 'Time: ${nextPrayer['time']}'
                                          : 'کاتژمێر ${nextPrayer['time']}'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              prayerIcons[nextPrayer['name']] ?? Icons.mosque_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SMART CONTEXTUAL TIME-BASED ADHKAR & REMINDER CARD
                    _buildSmartContextualCard(context, settings.language, times),
                    const SizedBox(height: 20),

                    // QUICK ACCESS CAROUSEL
                    _buildQuickAccessGrid(context, settings.language),
                    const SizedBox(height: 20),

                    // PRAYER TIMES HORIZONTAL OR VERTICAL CARDS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          settings.language == 'ku'
                              ? 'کاتەکانی نوێژی ئەمڕۆ'
                              : settings.language == 'ar'
                                  ? 'مواقيت الصلاة اليوم'
                                  : "Today's Prayer Times",
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Rabar'),
                        ),
                        BouncingButton(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const WorldPrayerTimesScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.public_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 5),
                                Text(
                                  settings.language == 'ku'
                                      ? 'هەموو وڵاتان'
                                      : (settings.language == 'ar' ? 'جميع الدول' : 'All Countries'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Rabar',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: times.entries.map((entry) {
                        final pName = entry.key;
                        final pTime = entry.value;
                        final icon = prayerIcons[pName] ?? Icons.mosque_rounded;
                        final localizedName = prayerLocalized[pName]?[langKey] ?? pName;
                        final isNext = nextPrayer['name'] == pName;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isNext ? Theme.of(context).colorScheme.primary.withOpacity(0.14) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isNext ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.06),
                              width: isNext ? 1.5 : 1.0,
                            ),
                            boxShadow: isNext
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 20,
                                    color: isNext ? Theme.of(context).colorScheme.primary : Colors.white70,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    localizedName,
                                    style: TextStyle(
                                      color: isNext ? Theme.of(context).colorScheme.primary : Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Rabar',
                                    ),
                                  ),
                                  if (isNext) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        settings.language == 'ar' ? 'القادمة' : (settings.language == 'en' ? 'Next' : 'داهاتوو'),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Rabar',
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                pTime,
                                style: TextStyle(
                                  color: isNext ? Theme.of(context).colorScheme.primary : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),

                    // DAILY WORSHIP HABITS RING & CHECKLIST
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isWorshipCompletedToday
                              ? Colors.orangeAccent.withOpacity(0.4)
                              : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: isWorshipCompletedToday ? 1.4 : 1.0,
                        ),
                        boxShadow: isWorshipCompletedToday
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: CircularProgressIndicator(
                                      value: progressVal,
                                      color: isWorshipCompletedToday
                                          ? Colors.orangeAccent
                                          : Theme.of(context).colorScheme.primary,
                                      backgroundColor: Colors.white.withOpacity(0.08),
                                      strokeWidth: 6,
                                    ),
                                  ),
                                  if (isWorshipCompletedToday)
                                    const Icon(
                                      Icons.local_fire_department_rounded,
                                      color: Colors.orangeAccent,
                                      size: 26,
                                    )
                                  else
                                    Text(
                                      '${(progressVal * 100).toInt()}%',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontFamily: 'Rabar',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            settings.language == 'en'
                                                ? 'Daily Worship Habits'
                                                : settings.language == 'ar'
                                                    ? 'عادات العبادة اليومية'
                                                    : 'تۆماری نوێژ و زیکرەکانی ئەمڕۆ',
                                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                                          ),
                                        ),
                                        _buildStreakPill(activity.streak, isWorshipCompletedToday, settings.language),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getHabitSubtitle(settings.language, isWorshipCompletedToday, completedHabitsCount),
                                      style: TextStyle(
                                        color: isWorshipCompletedToday
                                            ? Colors.orangeAccent.withOpacity(0.9)
                                            : Colors.white.withOpacity(0.55),
                                        fontSize: 12,
                                        fontFamily: 'Rabar',
                                        fontWeight: isWorshipCompletedToday ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 24),

                          // Habits Checklist Wrap Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildHabitChip('fajr', settings.language == 'en' ? 'Fajr' : settings.language == 'ar' ? 'الفجر' : 'بەیانی', Icons.wb_twilight_rounded),
                              _buildHabitChip('dhuhr', settings.language == 'en' ? 'Dhuhr' : settings.language == 'ar' ? 'الظهر' : 'نیوەڕۆ', Icons.light_mode_rounded),
                              _buildHabitChip('asr', settings.language == 'en' ? 'Asr' : settings.language == 'ar' ? 'العصر' : 'عەسڕ', Icons.cloud_queue_rounded),
                              _buildHabitChip('maghrib', settings.language == 'en' ? 'Maghrib' : settings.language == 'ar' ? 'المغرب' : 'مەغریب', Icons.nightlight_round),
                              _buildHabitChip('isha', settings.language == 'en' ? 'Isha' : settings.language == 'ar' ? 'العشاء' : 'عیشا', Icons.bedtime_rounded),
                              _buildHabitChip('adhkar', settings.language == 'en' ? 'Adhkar' : settings.language == 'ar' ? 'الأذكار' : 'زیکرەکان', Icons.fingerprint_rounded),
                              _buildHabitChip('quran', settings.language == 'en' ? 'Quran' : settings.language == 'ar' ? 'القرآن' : 'قورئان', Icons.menu_book_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // DAILY INSPIRATION VERSE CARD
                    if (_dailyVerse != null) ...[
                      _buildDailyVerseCard(settings.language),
                      SizedBox(height: 20),
                    ],

                    // HADITH OF THE DAY CARD
                    if (_todayHadith != null) ...[
                      _buildHadithOfTheDayCard(settings.language),
                      SizedBox(height: 20),
                    ],

                    // SUNNAH OF THE DAY CARD
                    if (_todaySunnah != null) ...[
                      _buildSunnahCard(settings.language),
                      SizedBox(height: 20),
                    ],

                    // Q&A OF THE DAY CARD
                    if (_todayQA != null) ...[
                      _buildQACard(settings.language),
                      SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHabitChip(String key, String label, IconData icon) {
    final isDone = _habits[key] ?? false;
    return BouncingButton(
      onTap: () {
        HapticFeedback.lightImpact();
        _toggleHabit(key, !isDone);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDone ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.08),
            width: 1.2,
          ),
          boxShadow: isDone
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDone ? Icons.check_circle_rounded : icon,
              color: isDone ? Colors.black : Theme.of(context).colorScheme.primary,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isDone ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Rabar',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEventBanner(String lang) {
    final eventName = lang == 'en'
        ? (_upcomingEvent!['name_en'] ?? _upcomingEvent!['title_en'] ?? '')
        : lang == 'ar'
            ? (_upcomingEvent!['name_ar'] ?? _upcomingEvent!['title_ar'] ?? _upcomingEvent!['name_ku'] ?? '')
            : (_upcomingEvent!['name_ku'] ?? _upcomingEvent!['title_ku'] ?? '');
    final days = (_upcomingEvent!['daysRemaining'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventName ?? '',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Rabar'),
                ),
                Text(
                  days == 0
                      ? (lang == 'en' ? 'Starts today!' : lang == 'ar' ? 'يبدأ اليوم!' : 'ئەمڕۆ دەستپێدەکات!')
                      : (lang == 'en' ? '$days days remaining' : lang == 'ar' ? 'متبقي $days أيام' : '$days ڕۆژی ماوە'),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyVerseCard(String lang) {
    final ar = _dailyVerse!['ar'] ?? '';
    final trans = lang == 'en' ? (_dailyVerse!['en'] ?? '') : (_dailyVerse!['ku'] ?? '');
    final refStr = _dailyVerse!['ref'] ?? '';
    final surahNum = (_dailyVerse!['surah_number'] as num?)?.toInt();
    final ayahNum = (_dailyVerse!['ayah_number'] as num?)?.toInt() ?? 1;
    final surahName = _dailyVerse!['surah']?.toString() ?? 'سورة';
    final cardTitle = lang == 'en' ? 'Verse of the Day' : lang == 'ar' ? 'آية اليوم' : 'ئایەتی ڕۆژ';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: surahNum != null && surahNum > 0
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SurahViewScreen(
                        surahId: surahNum,
                        surahNameAr: surahName,
                        surahNameKu: surahName,
                        surahNameEn: surahName,
                        initialAyahId: ayahNum,
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.format_quote, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              cardTitle,
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar', fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BouncingButton(
                          onTap: _nextVerse,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        BouncingButton(
                          onTap: () => Share.share('$ar\n\n$trans\n[$refStr]'),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.share, color: Colors.white70, size: 17),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ar,
                  style: GoogleFonts.amiri(fontSize: 18, color: Colors.white, height: 2.0, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),
                Text(
                  trans,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), height: 1.6, fontFamily: 'Rabar'),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '[$refStr]',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: 'Rabar',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (surahNum != null && surahNum > 0) ...[
                      const SizedBox(width: 8),
                      BouncingButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SurahViewScreen(
                                surahId: surahNum,
                                surahNameAr: surahName,
                                surahNameKu: surahName,
                                surahNameEn: surahName,
                                initialAyahId: ayahNum,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lang == 'en' ? 'Read Surah' : lang == 'ar' ? 'قراءة السورة' : 'خوێندنەوەی سورەتەکە',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Rabar',
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.primary, size: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHadithOfTheDayCard(String lang) {
    final h = _todayHadith!['hadith'] ?? _todayHadith!;
    final ar = h['arabic'] ?? '';
    final trans = lang == 'en' ? (h['english']?['text'] ?? h['kurdish']?['text'] ?? '') : (h['kurdish']?['text'] ?? '');
    final narrator = lang == 'en' ? (h['english']?['narrator'] ?? h['narrator_en'] ?? '') : (h['kurdish']?['narrator'] ?? h['narrator_ku'] ?? h['narrator_ar'] ?? '');
    final cardTitle = lang == 'en' ? 'Hadith of the Day' : lang == 'ar' ? 'حديث اليوم' : 'فەرموودەی ڕۆژ';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cardTitle,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar', fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BouncingButton(
                    onTap: _nextHadith,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BouncingButton(
                    onTap: () => Share.share('$ar\n\n$trans${narrator.isNotEmpty ? "\n\n[$narrator]" : ""}\n[$cardTitle]'),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share, color: Colors.white70, size: 17),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ar,
            style: GoogleFonts.amiri(fontSize: 17, color: Colors.white, height: 2.0, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          if (trans.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              trans,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), height: 1.6, fontFamily: 'Rabar'),
            ),
          ],
          if (narrator.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('[$narrator]', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar', fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSunnahCard(String lang) {
    final title = lang == 'en' ? (_todaySunnah!['en'] ?? '') : lang == 'ar' ? (_todaySunnah!['ar'] ?? '') : (_todaySunnah!['ku'] ?? '');
    final desc = lang == 'en' ? (_todaySunnah!['source_en'] ?? '') : (_todaySunnah!['source_ku'] ?? '');
    final cardTitle = lang == 'en' ? 'Sunnah of the Day' : lang == 'ar' ? 'سنة اليوم' : 'سوننەتی ڕۆژ';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.wb_sunny_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cardTitle,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar', fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BouncingButton(
                    onTap: _nextSunnah,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BouncingButton(
                    onTap: () => Share.share('$title\n${desc.isNotEmpty ? "[$desc]\n" : ""}[$cardTitle]'),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share, color: Colors.white70, size: 17),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Rabar', height: 1.5),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, height: 1.4, fontFamily: 'Rabar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQACard(String lang) {
    final q = lang == 'en' ? (_todayQA!['question_en'] ?? '') : lang == 'ar' ? (_todayQA!['question_ar'] ?? '') : (_todayQA!['question_ku'] ?? '');
    final a = lang == 'en' ? (_todayQA!['answer_en'] ?? '') : lang == 'ar' ? (_todayQA!['answer_ar'] ?? '') : (_todayQA!['answer_ku'] ?? '');
    final cardTitle = lang == 'en' ? 'Daily Q&A' : lang == 'ar' ? 'سؤال وجواب اليوم' : 'پرسیاری ئایینی ڕۆژ';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.format_quote, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cardTitle,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BouncingButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isQaExpanded = !_isQaExpanded);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isQaExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            q,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Rabar'),
          ),
          if (_isQaExpanded) ...[
            const Divider(color: Colors.white10, height: 20),
            Text(
              a,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8), height: 1.6, fontFamily: 'Rabar'),
            ),
          ],
        ],
      ),
    );
  }

  void _showCitySelector(BuildContext context, WidgetRef ref, List<dynamic> cities, String current, String language) {
    CitySelectorSheet.show(
      context,
      cities: cities.cast<City>(),
      currentCityId: current,
      language: language,
    );
  }


  Widget _buildQuickAccessGrid(BuildContext context, String lang) {
    final List<Map<String, dynamic>> items = [
      {
        'title': lang == 'ku' ? 'تەسبێح' : lang == 'ar' ? 'المسبحة' : 'Tasbih',
        'icon': Icons.fingerprint_rounded,
        'color': Theme.of(context).colorScheme.primary,
        'screen': const TasbihScreen(),
      },
      {
        'title': lang == 'ku' ? 'قیبلە' : lang == 'ar' ? 'القبلة' : 'Qibla',
        'icon': Icons.explore_rounded,
        'color': const Color(0xFF10B981),
        'screen': const QiblaScreen(),
      },
      {
        'title': lang == 'ku' ? 'خەتم' : lang == 'ar' ? 'الختم' : 'Khatam',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF3B82F6),
        'screen': const KhatamTrackerScreen(),
      },
      {
        'title': lang == 'ku' ? 'چۆنیەتی نوێژ' : lang == 'ar' ? 'كيفية الصلاة' : 'How to Pray',
        'icon': Icons.accessibility_new_rounded,
        'color': const Color(0xFF8B5CF6),
        'screen': const HowToPrayScreen(),
      },
      {
        'title': lang == 'ku' ? 'ناوەکان' : lang == 'ar' ? 'الأسماء' : '99 Names',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFFF59E0B),
        'screen': NamesScreen(),
      },
      {
        'title': lang == 'ku' ? 'زەکات' : lang == 'ar' ? 'الزكاة' : 'Zakat',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF10B981),
        'screen': const ZakatScreen(),
      },
      {
        'title': lang == 'ku' ? 'چیرۆک' : lang == 'ar' ? 'القصص' : 'Stories',
        'icon': Icons.child_care_rounded,
        'color': const Color(0xFFEC4899),
        'screen': const KidsStoriesScreen(),
      },
      {
        'title': lang == 'ku' ? 'حەج و عومرە' : lang == 'ar' ? 'الحج والعمرة' : 'Hajj',
        'icon': Icons.mosque_rounded,
        'color': const Color(0xFF64748B),
        'screen': HajjScreen(),
      },
      {
        'title': lang == 'ku' ? 'بابەتەکان' : lang == 'ar' ? 'المواضيع' : 'Topics',
        'icon': Icons.category_rounded,
        'color': Colors.cyan,
        'screen': const TopicsScreen(),
      },
      {
        'title': lang == 'ku' ? 'هەستەکان' : lang == 'ar' ? 'المشاعر' : 'Feelings',
        'icon': Icons.sentiment_satisfied_alt_rounded,
        'color': Colors.pinkAccent,
        'screen': const SituationsScreen(),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  lang == 'ku' ? 'دەستڕاگەیشتنی خێرا' : lang == 'ar' ? 'الوصول السريع' : 'Quick Shortcuts',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Rabar'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final Color itemColor = item['color'] as Color;

              return Container(
                width: 84,
                margin: const EdgeInsets.only(left: 10),
                child: BouncingButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => item['screen'] as Widget),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: itemColor.withOpacity(0.3), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: itemColor.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: itemColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item['icon'] as IconData, color: itemColor, size: 20),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            (item['title'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rabar',
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static Map<String, int> _gregorianToHijri(DateTime date) {
    int day = date.day;
    int month = date.month;
    int year = date.year;

    if (month < 3) {
      year -= 1;
      month += 12;
    }

    int a = (year / 100).floor();
    int b = 2 - a + (a / 4).floor();
    int jd = (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day + b - 1524;

    if (jd > 2299160) {
      a = ((jd - 1867216.25) / 36524.25).floor();
      b = jd + 1 + a - (a / 4).floor();
    } else {
      b = jd;
    }

    int z = jd - 1948440 + 10632;
    int n = ((z - 1) / 10631).floor();
    z = z - 10631 * n + 354;
    int j = ((10985 - z) / 5316).floor() * ((50 * z) / 17719).floor() +
        (z / 5670).floor() * ((43 * z) / 15238).floor();
    z = z - ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() -
        (j / 16).floor() * ((15238 * j) / 43).floor() + 29;
    int hMonth = ((24 * z) / 709).floor();
    int hDay = z - ((709 * hMonth) / 24).floor();
    int hYear = 30 * n + j - 30;

    return {'year': hYear, 'month': hMonth.clamp(1, 12), 'day': hDay.clamp(1, 30)};
  }

  String _formatHijriDate(DateTime now, String lang) {
    final hijri = _gregorianToHijri(now);
    final hDay = hijri['day']!;
    final hMonth = hijri['month']!;
    final hYear = hijri['year']!;

    final monthsKu = [
      'مۆحەڕەم', 'سەفەر', 'ڕەبیعی یەکەم', 'ڕەبیعی دووەم',
      'جومادەلئوولا', 'جومادەلئاخیرە', 'ڕەجەب', 'شەعبان',
      'ڕەمەزان', 'شەووال', 'زولقەعدە', 'زولحەججە'
    ];
    final monthsAr = [
      'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر',
      'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
      'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
    ];
    final monthsEn = [
      'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
      'Jumada al-Ula', 'Jumada al-Akhirah', 'Rajab', 'Sha\'ban',
      'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
    ];

    if (lang == 'ar') {
      return '${now.day}/${now.month}/${now.year} م • $hDay ${monthsAr[hMonth - 1]} $hYear هـ';
    } else if (lang == 'en') {
      return '${now.day}/${now.month}/${now.year} AD • $hDay ${monthsEn[hMonth - 1]} $hYear AH';
    } else {
      return '${now.day}/${now.month}/${now.year} ز • $hDayی ${monthsKu[hMonth - 1]} $hYear کۆچی';
    }
  }

  Widget _buildSmartContextualCard(BuildContext context, String lang, Map<String, String> times) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final isFriday = now.weekday == DateTime.friday;

    int parseMinutes(String? timeStr, int fallback) {
      if (timeStr == null) return fallback;
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          return h * 60 + m;
        }
      }
      return fallback;
    }

    final fajrMinutes = parseMinutes(times['Fajr'], 4 * 60 + 30);
    final asrMinutes = parseMinutes(times['Asr'], 15 * 60 + 30);
    final ishaMinutes = parseMinutes(times['Isha'], 19 * 60 + 30);

    final bool isMorningTime = currentMinutes >= fajrMinutes && currentMinutes < asrMinutes;
    final bool isEveningTime = currentMinutes >= asrMinutes && currentMinutes < ishaMinutes;

    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardColor;

    final String title;
    final String subtitle;
    final String badge;
    final Widget actionButtons;

    if (isMorningTime) {
      if (isFriday) {
        title = lang == 'ar'
            ? 'أذكار الصباح وسُورَة الكَهف'
            : (lang == 'en' ? 'Morning Adhkar & Surah Al-Kahf' : 'زیکرەکانی بەیانیان و سوورەتی کەهف');
        subtitle = lang == 'ar'
            ? 'من الفجر إلى العصر: ابدأ يومك بأذكار الصباح وقراءة سورة الكهف المباركة'
            : (lang == 'en'
                ? 'From Fajr to Asr: Start your day with morning adhkar and Surah Al-Kahf'
                : 'لە نێوان بانگی بەیانی تا عەسر؛ بەرەکەتی ئەزکار و خوێندنەوەی سوورەتی کەهف لە ڕۆژی هەینیدا');
        badge = lang == 'ar' ? 'الجمعة المباركة' : (lang == 'en' ? 'Blessed Friday' : 'هەینی پیرۆز');
        actionButtons = Row(
          children: [
            Expanded(
              child: BouncingButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdhkarDetailsScreen(
                        categoryId: 'morning',
                        categoryName: lang == 'ar' ? 'أذكار الصباح' : (lang == 'en' ? 'Morning Adhkar' : 'ئەزکاری بەیانی'),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_stories, size: 18, color: Colors.black),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            lang == 'ar' ? 'أذكار الصباح' : (lang == 'en' ? 'Morning Adhkar' : 'ئەزکاری بەیانی'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar', fontSize: 13, color: Colors.black),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BouncingButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SurahViewScreen(
                        surahId: 18,
                        surahNameKu: 'کەهف',
                        surahNameAr: 'الكهف',
                        surahNameEn: 'Al-Kahf',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primary.withOpacity(0.5), width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 18, color: primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            lang == 'ar' ? 'سورة الكهف' : (lang == 'en' ? 'Surah Al-Kahf' : 'سوورەتی کەهف'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar', fontSize: 13, color: Colors.white),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        // Morning Adhkar (Fajr to Asr)
        title = lang == 'ar'
            ? 'أذكار الصباح'
            : (lang == 'en' ? 'Morning Adhkar' : 'زیکرەکانی بەیانیان');
        subtitle = lang == 'ar'
            ? 'من صلاة الفجر إلى العصر؛ ابدأ يومك بذكر الله وتحصين النفس بأذكار الصباح'
            : (lang == 'en'
                ? 'From Fajr to Asr; start your morning with the remembrance of Allah and morning adhkar'
                : 'لە بانگی بەیانی تا بانگی عەسر؛ ڕۆژەکەت بە بەرەکەتی یادی خودا و زیکرەکانی بەیانی دەستپێبکە');
        badge = lang == 'ar' ? 'من الفجر إلى العصر' : (lang == 'en' ? 'Fajr to Asr' : 'لە بەیانی تا عەسر');
        actionButtons = SizedBox(
          width: double.infinity,
          child: BouncingButton(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdhkarDetailsScreen(
                    categoryId: 'morning',
                    categoryName: lang == 'ar' ? 'أذكار الصباح' : (lang == 'en' ? 'Morning Adhkar' : 'ئەزکاری بەیانی'),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_stories, size: 18, color: Colors.black),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        lang == 'ar'
                            ? 'قراءة أذكار الصباح (الآن)'
                            : (lang == 'en' ? 'Read Morning Adhkar (Now)' : 'خوێندنەوەی زیکرەکانی بەیانی (ئێستا)'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar', fontSize: 13, color: Colors.black),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } else if (isEveningTime) {
      // Evening Adhkar (Asr to Isha)
      title = lang == 'ar'
          ? 'أذكار المساء'
          : (lang == 'en' ? 'Evening Adhkar' : 'زیکرەکانی ئێواران');
      subtitle = lang == 'ar'
          ? 'من صلاة العصر إلى العشاء؛ حصّن نفسك وبيتك بأذكار المساء المأثورة'
          : (lang == 'en'
              ? 'From Asr to Isha; protect yourself and your home with evening adhkar'
              : 'لە بانگی عەسر تا بانگی عیشا؛ بە بەرەکەتی زیکرەکانی ئێواران ماڵ و گیانت بپارێزە');
      badge = lang == 'ar' ? 'من العصر إلى العشاء' : (lang == 'en' ? 'Asr to Isha' : 'لە عەسر تا عیشا');
      actionButtons = SizedBox(
        width: double.infinity,
        child: BouncingButton(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdhkarDetailsScreen(
                  categoryId: 'evening',
                  categoryName: lang == 'ar' ? 'أذكار المساء' : (lang == 'en' ? 'Evening Adhkar' : 'ئەزکاری ئێواران'),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.nightlight_round, size: 18, color: Colors.black),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      lang == 'ar'
                          ? 'قراءة أذكار المساء (الآن)'
                          : (lang == 'en' ? 'Read Evening Adhkar (Now)' : 'خوێندنەوەی زیکرەکانی ئێواران (ئێستا)'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar', fontSize: 13, color: Colors.black),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Bedtime Adhkar & Surah Al-Mulk (Isha to Fajr)
      title = lang == 'ar'
          ? 'أذكار النوم وسورة الملك'
          : (lang == 'en' ? 'Bedtime Adhkar & Surah Al-Mulk' : 'زیکرەکانی خەوتن و سوورەتی موڵک');
      subtitle = lang == 'ar'
          ? 'من صلاة العشاء إلى الفجر؛ سورة الملك تنجي من عذاب القبر، مع أذكار النوم'
          : (lang == 'en'
              ? 'From Isha to Fajr; Surah Al-Mulk protects from grave punishment, with sleep adhkar'
              : 'لە بانگی عیشا تا بانگی بەیانی؛ سوورەتی موڵک و زیکرەکانی پێش خەوتن بخوێنە');
      badge = lang == 'ar' ? 'من العشاء إلى الفجر' : (lang == 'en' ? 'Isha to Fajr' : 'لە عیشا تا بەیانی');
      actionButtons = Row(
        children: [
          Expanded(
            child: BouncingButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SurahViewScreen(
                      surahId: 67,
                      surahNameKu: 'موڵک',
                      surahNameAr: 'الملك',
                      surahNameEn: 'Al-Mulk',
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book, size: 18, color: Colors.black),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          lang == 'ar' ? 'سورة الملك' : (lang == 'en' ? 'Surah Al-Mulk' : 'سوورەتی موڵک'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar', fontSize: 13, color: Colors.black),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BouncingButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdhkarDetailsScreen(
                      categoryId: '2',
                      categoryName: lang == 'ar' ? 'أذكار النوم' : (lang == 'en' ? 'Sleep Adhkar' : 'ئەزکاری خەوتن'),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withOpacity(0.5), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bedtime_outlined, size: 18, color: primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          lang == 'ar' ? 'أذكار النوم' : (lang == 'en' ? 'Sleep Adhkar' : 'ئەزکاری خەوتن'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar', fontSize: 13, color: Colors.white),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Rabar',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withOpacity(0.35)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, height: 1.4, fontFamily: 'Rabar'),
          ),
          const SizedBox(height: 14),
          actionButtons,
        ],
      ),
    );
  }
}
