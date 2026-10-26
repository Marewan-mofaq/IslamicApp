import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/city.dart';
import 'providers/settings_provider.dart';
import 'services/data_service.dart';
import 'services/notification_service.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/quran_audio_handler.dart';
import 'services/widget_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
QuranAudioHandler? globalAudioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataService.loadAwqafPrayerDatabase();
  final prefs = await SharedPreferences.getInstance();
  NotificationService.globalNavigatorKey = appNavigatorKey;
  await NotificationService.init();

  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {},
          ),
        ),
      );
      globalAudioHandler = await AudioService.init(
        builder: () => QuranAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.islamicapp.app.quran_audio',
          androidNotificationChannelName: 'دەنگی خوێندنەوەی قورئان',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );
    } catch (e) {
      debugPrint('[AudioService] Init error: $e');
    }
  }

  final lang = prefs.getString('language') ?? 'ku';
  final morning = prefs.getBool('notif_adhkar_morning') ?? true;
  final evening = prefs.getBool('notif_adhkar_evening') ?? true;
  final bedtime = prefs.getBool('notif_adhkar_bedtime') ?? true;
  final friday = prefs.getBool('notif_adhkar_friday') ?? true;
  NotificationService.scheduleDailyAdhkarNotifications(
    language: lang,
    morning: morning,
    evening: evening,
    bedtime: bedtime,
    friday: friday,
  );

  // Trigger initial home screen widget update
  WidgetService.updateFromPreferences(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

// FutureProvider to load cities
final citiesFutureProvider = FutureProvider<List<City>>((ref) async {
  return DataService.loadCities();
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final prefs = ref.watch(sharedPreferencesProvider);
    final isFirstLaunchDone = prefs.getBool('is_first_launch_done') ?? false;

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Islam App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: theme.backgroundColor,
        cardColor: theme.cardColor,
        colorScheme: ColorScheme.dark(
          primary: theme.primaryColor,
          secondary: theme.secondaryColor,
          surface: theme.cardColor,
        ),
        cardTheme: CardThemeData(
          color: theme.cardColor,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: theme.cardColor,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: theme.cardColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Rabar',
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: theme.primaryColor.withOpacity(0.5), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Rabar',
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: theme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Rabar',
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: theme.cardColor,
          contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          },
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Rabar',
          fontFamilyFallback: const [
            'Noto Color Emoji',
            'Apple Color Emoji',
            'Segoe UI Emoji',
            'Segoe UI Symbol',
            'Noto Naskh Arabic',
            'Noto Sans Arabic',
            'Amiri',
            'Segoe UI',
            'Tahoma',
            'sans-serif',
          ],
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: theme.backgroundColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Rabar',
            fontFamilyFallback: [
              'Noto Naskh Arabic',
              'Noto Sans Arabic',
              'Amiri',
              'Segoe UI',
              'Tahoma',
              'sans-serif',
            ],
          ),
        ),
      ),
      home: isFirstLaunchDone ? const MainNavigation() : const OnboardingScreen(),
    );
  }
}
