import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'prayer_service.dart';
import '../screens/adhan_playing_dialog.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static void _logError(dynamic e) {
    if (e is MissingPluginException) return;
    if (e.toString().contains('LateInitializationError')) return;
    debugPrint('[NotificationService] Error: $e');
  }

  static GlobalKey<NavigatorState>? globalNavigatorKey;
  static AudioPlayer? _activeInAppAdhanPlayer;

  static void setActiveInAppAdhanPlayer(AudioPlayer? player) {
    _activeInAppAdhanPlayer = player;
  }

  static Function(String action)? onQuranPlaybackAction;
  static const int quranNotificationId = 9999;
  static const String quranPlaybackChannelId = 'quran_playback_channel';

  /// One-time purge flag for legacy alarms from older app versions.
  static const String _legacyPurgeKey = 'notif_legacy_purge_v4_done';

  /// Serializes prayer scheduling so overlapping calls (startup, GPS, resume,
  /// settings change) never interleave their cancel/schedule phases.
  static Future<void> _scheduleChain = Future.value();
  static int _scheduleGeneration = 0;

  static const Map<String, String> adhanVoiceNames = {
    'mishary': 'مشاری ڕاشید ئەلعەفاسی',
    'nasser': 'ناسر ئەلقەتامی',
    'ahmed': 'ئەحمەد ئەلعیمادی',
    'majed': 'ماجد ئەلحەمەسانی',
    'mokhtar': 'مختار حاج سلیمان',
  };

  static const Map<String, String> fajrAdhanVoiceNames = {
    'mishary_fajr': 'مشاری ڕاشید ئەلعەفاسی (بانگی بەیانی)',
    'makkah_fajr': 'حەرەمی مەککە (بانگی بەیانی)',
  };

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback to Kurdistan/Iraq timezone, then UTC as ultimate fallback.
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    if (!isSupportedPlatform) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          handleNotificationResponse(response);
        },
      );
    } catch (e) {
      _logError(e);
    }

    // Purge legacy/phantom scheduled prayer alarms from previous app versions
    // ONCE only. Only cancel prayer IDs (1-50), NOT adhkar or other notifications.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_legacyPurgeKey) != true) {
        for (int i = 0; i <= 50; i++) {
          await _notificationsPlugin.cancel(i);
        }
        await prefs.setBool(_legacyPurgeKey, true);
      }
    } catch (e) {
      _logError(e);
    }

    // Register all notification channels for Android
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      try {
        // 1. Standard bell sound channel
        // 1. Standard bell sound channel (uses alarm stream so it's always audible)
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            'adhan_alarm_bell_v4',
            'زەنگی ئاسایی (Bell)',
            description: 'ئاگادارکردنەوەی کاتەکانی نوێژ بە زەنگ',
            importance: Importance.max,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
          ),
        );

        // 2. Silent channel
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            'adhan_channel_silent',
            'بێدەنگ (Silent)',
            description: 'ئاگادارکردنەوەی بێدەنگ بۆ نوێژ',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
          ),
        );

        // 3. Quran Media Playback Ongoing Channel
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            'quran_playback_channel',
            'دەنگی خوێندنەوەی قورئان (Quran Playback)',
            description: 'کۆنتڕۆڵی دەنگی قورئان لەسەر شاشەی قفڵ و نۆتفکەیشن',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
          ),
        );

        // Purge all legacy channels from previous versions
        await androidImpl.deleteNotificationChannel('adhan_channel_bell');
        for (final voiceId in adhanVoiceNames.keys) {
          await androidImpl.deleteNotificationChannel('adhan_channel_v3_$voiceId');
          await androidImpl.deleteNotificationChannel('adhan_channel_v2_$voiceId');
          await androidImpl.deleteNotificationChannel('adhan_channel_$voiceId');
        }
        for (final voiceId in fajrAdhanVoiceNames.keys) {
          await androidImpl.deleteNotificationChannel('adhan_channel_v3_$voiceId');
          await androidImpl.deleteNotificationChannel('adhan_channel_v2_$voiceId');
          await androidImpl.deleteNotificationChannel('adhan_channel_$voiceId');
        }

        // 4. Dedicated Alarm-Grade channels for each custom Regular Adhan voice from res/raw (AudioAttributesUsage.alarm)
        for (final entry in adhanVoiceNames.entries) {
          final voiceId = entry.key;
          final voiceTitle = entry.value;

          await androidImpl.createNotificationChannel(
            AndroidNotificationChannel(
              'adhan_alarm_v4_$voiceId',
              'بانگی ئاسایی ($voiceTitle)',
              description: 'ئاگادارکردنەوەی بانگی ئاسایی بە دەنگی $voiceTitle',
              importance: Importance.max,
              playSound: true,
              sound: RawResourceAndroidNotificationSound(voiceId),
              audioAttributesUsage: AudioAttributesUsage.alarm,
              enableVibration: true,
            ),
          );
        }

        // 5. Dedicated Alarm-Grade channels for Fajr Adhan (AudioAttributesUsage.alarm)
        for (final entry in fajrAdhanVoiceNames.entries) {
          final voiceId = entry.key;
          final voiceTitle = entry.value;

          await androidImpl.createNotificationChannel(
            AndroidNotificationChannel(
              'adhan_alarm_v4_$voiceId',
              'بانگی بەیانی ($voiceTitle)',
              description: 'ئاگادارکردنەوەی بانگی بەیانی بە دەنگی $voiceTitle',
              importance: Importance.max,
              playSound: true,
              sound: RawResourceAndroidNotificationSound(voiceId),
              audioAttributesUsage: AudioAttributesUsage.alarm,
              enableVibration: true,
            ),
          );
        }

        // 4. Dedicated channel for smart daily Adhkar & Friday reminders
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            'adhkar_channel',
            'زیکرەکان و ڕۆژی هەینی (Adhkar & Friday)',
            description: 'ئاگادارکردنەوەی زیکرەکانی بەیانی، ئێواران، خەوتن و سوورەتی کەهف',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      } catch (e) {
        _logError(e);
      }
    }

    await requestPermissions();
  }

  static Future<void> requestPermissions() async {
    if (!isSupportedPlatform) return;
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
        await androidImpl.requestExactAlarmsPermission();
      }

      final iosImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      _logError(e);
    }
  }

  static Future<void> schedulePrayerNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String soundType = 'adhan',
    String adhanVoice = 'mishary',
    String fajrAdhanVoice = 'mishary_fajr',
    bool isFajr = false,
    bool repeatingDaily = false,
  }) async {
    if (!isSupportedPlatform) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    final isSilent = soundType == 'silent';
    final isBell = soundType == 'bell';
    final isAdhan = soundType == 'adhan';

    String channelId;
    String channelName;
    AndroidNotificationSound? androidSound;
    String? iosSound;

    if (isSilent) {
      channelId = 'adhan_channel_silent';
      channelName = 'بێدەنگ (Silent)';
      androidSound = null;
      iosSound = null;
    } else if (isBell) {
      channelId = 'adhan_alarm_bell_v4';
      channelName = 'زەنگی ئاسایی (Bell)';
      androidSound = null;
      iosSound = null;
    } else if (isFajr) {
      // Fajr Prayer: Use user-selected Fajr adhan voice (with "الصلاة خير من النوم")
      final voice = fajrAdhanVoice.isNotEmpty ? fajrAdhanVoice : 'mishary_fajr';
      channelId = 'adhan_alarm_v4_$voice';
      final vName = fajrAdhanVoiceNames[voice] ?? voice;
      channelName = 'بانگی بەیانی ($vName)';
      androidSound = RawResourceAndroidNotificationSound(voice);
      iosSound = '$voice.caf';
    } else {
      // Other Prayers (Dhuhr, Asr, Maghrib, Isha): Strictly play Regular Adhan without "الصلاة خير من النوم"
      final voice = adhanVoice.isNotEmpty ? adhanVoice : 'mishary';
      channelId = 'adhan_alarm_v4_$voice';
      final vName = adhanVoiceNames[voice] ?? voice;
      channelName = 'بانگی ئاسایی ($vName)';
      androidSound = RawResourceAndroidNotificationSound(voice);
      iosSound = '$voice.caf';
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isFajr ? 'ئاگادارکردنەوەی بانگی بەیانی' : 'کاتی بانگدانی نوێژەکان',
      importance: isSilent ? Importance.low : Importance.max,
      priority: isSilent ? Priority.low : Priority.high,
      playSound: !isSilent,
      sound: androidSound,
      enableVibration: !isSilent,
      audioAttributesUsage: isSilent ? AudioAttributesUsage.notification : AudioAttributesUsage.alarm,
      category: isSilent ? AndroidNotificationCategory.reminder : AndroidNotificationCategory.alarm,
      fullScreenIntent: isAdhan,
      visibility: NotificationVisibility.public,
      timeoutAfter: isAdhan ? 30 * 60 * 1000 : null, // Auto-dismiss after 30 minutes
      styleInformation: BigTextStyleInformation(body),
      actions: isAdhan
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'stop_adhan',
                '⏹️ ڕاگرتنی بانگ (Stop)',
                cancelNotification: true,
                showsUserInterface: true,
              ),
            ]
          : null,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: !isSilent,
        sound: isAdhan ? iosSound : null,
      ),
    );

    final payload = isAdhan
        ? 'prayer_adhan:$title:${isFajr ? (fajrAdhanVoice.isNotEmpty ? fajrAdhanVoice : "mishary_fajr") : (adhanVoice.isNotEmpty ? adhanVoice : "nasser")}'
        : null;

    // Safe fallback details (default bell sound on alarm stream) in case the
    // custom adhan sound/channel fails on this device.
    final NotificationDetails bellDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'adhan_alarm_bell_v4',
        'زەنگی ئاسایی (Bell)',
        channelDescription: 'ئاگادارکردنەوەی کاتەکانی نوێژ بە زەنگ',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final canExact = await _canScheduleExact();
    final attempts = <(NotificationDetails, AndroidScheduleMode)>[
      if (canExact) (details, AndroidScheduleMode.alarmClock),
      if (canExact) (details, AndroidScheduleMode.exactAllowWhileIdle),
      (details, AndroidScheduleMode.inexactAllowWhileIdle),
      if (!isSilent && canExact) (bellDetails, AndroidScheduleMode.alarmClock),
      if (!isSilent && canExact) (bellDetails, AndroidScheduleMode.exactAllowWhileIdle),
      if (!isSilent) (bellDetails, AndroidScheduleMode.inexactAllowWhileIdle),
    ];

    Object? lastError;
    for (final (attemptDetails, mode) in attempts) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          attemptDetails,
          payload: payload,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeatingDaily ? DateTimeComponents.time : null,
        );
        return;
      } catch (e) {
        lastError = e;
        debugPrint('[NotificationService] Schedule #$id with $mode failed: $e');
      }
    }
    if (lastError != null) _logError(lastError);
  }

  static bool? _canExactCache;

  /// Whether the OS currently allows exact alarms (Android 12+ can revoke it).
  static Future<bool> _canScheduleExact({bool refresh = false}) async {
    if (!refresh && _canExactCache != null) return _canExactCache!;
    bool result = true;
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        result = await androidImpl.canScheduleExactNotifications() ?? true;
      }
    } catch (e) {
      _logError(e);
    }
    _canExactCache = result;
    return result;
  }

  static Future<void> stopAdhan([int? notifId]) async {
    try {
      if (_activeInAppAdhanPlayer != null) {
        final player = _activeInAppAdhanPlayer!;
        _activeInAppAdhanPlayer = null;
        await player.stop();
        await player.dispose();
      }
    } catch (e) {
      debugPrint('[NotificationService] Error stopping adhan: $e');
    }

    if (!isSupportedPlatform) return;

    try {
      if (notifId != null) {
        await _notificationsPlugin.cancel(notifId);
      } else {
        // Only dismiss active notifications, don't cancel future scheduled ones
        final activeNotifs = await _notificationsPlugin.getActiveNotifications();
        for (final notif in activeNotifs) {
          if (notif.id != null && notif.id! >= 1 && notif.id! <= 50) {
            await _notificationsPlugin.cancel(notif.id!);
          }
        }
      }
    } catch (e) {
      _logError(e);
    }
  }

  static void handleNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'stop_adhan') {
      stopAdhan(response.id);
      return;
    }

    if (response.actionId != null && response.actionId!.startsWith('quran_')) {
      onQuranPlaybackAction?.call(response.actionId!);
      if (response.actionId == 'quran_stop') {
        dismissQuranPlaybackNotification();
      }
      return;
    }

    final payload = response.payload;
    if (payload != null && payload.startsWith('prayer_adhan:')) {
      final parts = payload.split(':');
      final prayerTitle = parts.length > 1 ? parts[1] : 'Fajr';
      final voice = parts.length > 2 ? parts[2] : 'mishary_fajr';

      final navContext = globalNavigatorKey?.currentContext;
      if (navContext != null) {
        AdhanPlayingDialog.show(
          navContext,
          prayerName: prayerTitle,
          voiceId: voice,
          autoPlayAudio: false,
        );
      }
    }
  }

  static Future<void> showQuranPlaybackNotification({
    required String surahName,
    required String reciterName,
    required bool isPlaying,
    String? ayahInfo,
  }) async {
    if (!isSupportedPlatform) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        'quran_playback_channel',
        'دەنگی خوێندنەوەی قورئان (Quran Playback)',
        channelDescription: 'کۆنتڕۆڵی دەنگی قورئان لەسەر شاشەی قفڵ و نۆتفکەیشن',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: isPlaying,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: false,
        actions: [
          const AndroidNotificationAction(
            'quran_prev',
            '⏮️',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'quran_play_pause',
            isPlaying ? '⏸️' : '▶️',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            'quran_next',
            '⏭️',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            'quran_stop',
            '⏹️',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      );

      await _notificationsPlugin.show(
        quranNotificationId,
        surahName,
        ayahInfo != null && ayahInfo.isNotEmpty ? '$reciterName • $ayahInfo' : reciterName,
        details,
        payload: 'quran_audio_open',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing quran playback notif: $e');
    }
  }

  static Future<void> dismissQuranPlaybackNotification() async {
    if (!isSupportedPlatform) return;
    try {
      await _notificationsPlugin.cancel(quranNotificationId);
    } catch (_) {}
  }

  // Cancel only prayer notifications (IDs 1..500), keeping Adhkar notifications (501..504) intact
  static Future<void> cancelPrayerNotifications() async {
    if (!isSupportedPlatform) return;
    try {
      final activeNotifs = await _notificationsPlugin.getActiveNotifications();
      for (final notif in activeNotifs) {
        if (notif.id != null && notif.id! >= 1 && notif.id! <= 50) {
          await _notificationsPlugin.cancel(notif.id!);
        }
      }
    } catch (e) {
      _logError(e);
    }
    // Also cancel any pending (future) prayer notifications
    try {
      final pendingNotifs = await _notificationsPlugin.pendingNotificationRequests();
      for (final notif in pendingNotifs) {
        if (notif.id >= 1 && notif.id <= 50) {
          await _notificationsPlugin.cancel(notif.id);
        }
      }
    } catch (e) {
      _logError(e);
    }
  }

  static Future<void> scheduleDailyPrayers({
    required Map<String, String> prayerTimes,
    required Map<String, bool> enabledPrayers,
    required String language,
    required String soundType,
    String adhanVoice = 'mishary',
    String fajrAdhanVoice = 'mishary_fajr',
    double? latitude,
    double? longitude,
    String? method,
    String? asrMadhab,
    Map<String, int>? offsets,
    String? cityId,
    String? countryCode,
  }) {
    if (!isSupportedPlatform) return Future.value();
    final generation = ++_scheduleGeneration;
    _scheduleChain = _scheduleChain.then((_) async {
      // A newer request was queued meanwhile — skip this stale one.
      if (generation != _scheduleGeneration) return;
      await _scheduleDailyPrayersImpl(
        prayerTimes: prayerTimes,
        enabledPrayers: enabledPrayers,
        language: language,
        soundType: soundType,
        adhanVoice: adhanVoice,
        fajrAdhanVoice: fajrAdhanVoice,
        latitude: latitude,
        longitude: longitude,
        method: method,
        asrMadhab: asrMadhab,
        offsets: offsets,
        cityId: cityId,
        countryCode: countryCode,
      );
    }).catchError((Object e) {
      _logError(e);
    });
    return _scheduleChain;
  }

  static Future<void> _scheduleDailyPrayersImpl({
    required Map<String, String> prayerTimes,
    required Map<String, bool> enabledPrayers,
    required String language,
    required String soundType,
    String adhanVoice = 'mishary',
    String fajrAdhanVoice = 'mishary_fajr',
    double? latitude,
    double? longitude,
    String? method,
    String? asrMadhab,
    Map<String, int>? offsets,
    String? cityId,
    String? countryCode,
  }) async {
    if (!isSupportedPlatform) return;
    // Re-check exact alarm permission each run (user may have toggled it).
    await _canScheduleExact(refresh: true);
    try {
      // 1. Cancel previous prayer notifications only (leaving Adhkar notifications untouched)
      await cancelPrayerNotifications();

      final now = DateTime.now();

      final Map<String, int> prayerIndices = {
        'Fajr': 1,
        'Dhuhr': 2,
        'Asr': 3,
        'Maghrib': 4,
        'Isha': 5,
      };

      final Map<String, Map<String, String>> localizedNames = {
        'Fajr': {'ku': 'نوێژی بەیانی', 'ar': 'صلاة الفجر', 'en': 'Fajr Prayer'},
        'Dhuhr': {'ku': 'نوێژی نیوەڕۆ', 'ar': 'صلاة الظهر', 'en': 'Dhuhr Prayer'},
        'Asr': {'ku': 'نوێژی عەسڕ', 'ar': 'صلاة العصر', 'en': 'Asr Prayer'},
        'Maghrib': {'ku': 'نوێژی مەغریب', 'ar': 'صلاة المغرب', 'en': 'Maghrib Prayer'},
        'Isha': {'ku': 'نوێژی عیشا', 'ar': 'صلاة العشاء', 'en': 'Isha Prayer'},
      };

      // Schedule 10 days in advance (10 days * 5 prayers = 50 notifications, strictly within iOS 64 limit and Android limit)
      // Every prayer is scheduled as an exact ONE-SHOT alarm: no repeating collisions, strictly ONE adhan per prayer time!
      const int daysToSchedule = 10;

      for (int dayOffset = 0; dayOffset < daysToSchedule; dayOffset++) {
        final targetDate = DateTime(now.year, now.month, now.day + dayOffset);

        Map<String, String> dayPrayerTimes;
        try {
          dayPrayerTimes = dayOffset == 0
              ? prayerTimes
              : ((cityId != null || (latitude != null && longitude != null))
                  ? PrayerService.calculateTimes(
                      latitude: latitude ?? 0.0,
                      longitude: longitude ?? 0.0,
                      method: method ?? 'KRG',
                      asrMadhab: asrMadhab ?? 'Shafi',
                      offsets: offsets ?? const {},
                      cityId: cityId,
                      countryCode: countryCode,
                      targetDate: targetDate,
                    )
                  : prayerTimes);
        } catch (e) {
          _logError(e);
          continue; // Skip only this day, keep scheduling the others
        }

        for (final entry in dayPrayerTimes.entries) {
          final pName = entry.key;
          final timeStr = entry.value;

          if (pName == 'Sunrise') continue;
          if (!prayerIndices.containsKey(pName)) continue;
          if (enabledPrayers[pName] == false) continue;

          final parts = timeStr.split(':');
          if (parts.length != 2) continue;
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h == null || m == null) continue;

          DateTime scheduledDate = DateTime(targetDate.year, targetDate.month, targetDate.day, h, m, 0, 0);
          if (scheduledDate.isBefore(now)) {
            // Already passed today, skip to future days
            continue;
          }

          final pIndex = prayerIndices[pName]!;
          final notifId = dayOffset * 5 + pIndex;
          final pTitle = localizedNames[pName]?[language] ?? '$pName Prayer';
          final pBody = language == 'ku'
              ? 'کاتی $pTitle هات ($timeStr)'
              : language == 'ar'
                  ? 'حان الآن وقت $pTitle ($timeStr)'
                  : "It's time for $pTitle ($timeStr)";

          final isFajr = pName == 'Fajr';

          try {
            await schedulePrayerNotification(
              id: notifId,
              title: pTitle,
              body: pBody,
              scheduledDate: scheduledDate,
              soundType: soundType,
              adhanVoice: adhanVoice,
              fajrAdhanVoice: fajrAdhanVoice,
              isFajr: isFajr,
              repeatingDaily: false, // Strictly ONE-SHOT: Never duplicates!
            );
          } catch (e) {
            // Never let one prayer failure abort the remaining prayers
            _logError(e);
          }
        }
      }
    } catch (e) {
      _logError(e);
    }
  }

  static Future<void> scheduleDailyAdhkarNotifications({
    required String language,
    bool morning = true,
    bool evening = true,
    bool bedtime = true,
    bool friday = true,
  }) async {
    if (!isSupportedPlatform) return;
    try {
      // Cancel existing adhkar notifications
      await _notificationsPlugin.cancel(501);
      await _notificationsPlugin.cancel(502);
      await _notificationsPlugin.cancel(503);
      await _notificationsPlugin.cancel(504);

      final now = tz.TZDateTime.now(tz.local);

      // 1. Morning Adhkar (07:00 AM)
      if (morning) {
        var morningTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7, 0);
        if (morningTime.isBefore(now)) {
          morningTime = morningTime.add(const Duration(days: 1));
        }
        await _notificationsPlugin.zonedSchedule(
          501,
          language == 'ar' ? '🌅 أذكار الصباح' : (language == 'en' ? '🌅 Morning Adhkar' : '🌅 زیکرەکانی بەیانیان'),
          language == 'ar'
              ? 'ابدأ يومك بذكر الله وتحصين النفس بأذكار الصباح المباركة'
              : (language == 'en'
                  ? 'Start your day with the remembrance of Allah and morning adhkar'
                  : 'ڕۆژەکەت بە یادی خودا و زیکرە پیرۆزەکانی بەیانی دەست پێبکە'),
          morningTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'adhkar_channel',
              'زیکرەکان و ڕۆژی هەینی (Adhkar & Friday)',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      // 2. Evening Adhkar (05:30 PM / 17:30)
      if (evening) {
        var eveningTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 17, 30);
        if (eveningTime.isBefore(now)) {
          eveningTime = eveningTime.add(const Duration(days: 1));
        }
        await _notificationsPlugin.zonedSchedule(
          502,
          language == 'ar' ? '🌙 أذكار المساء' : (language == 'en' ? '🌙 Evening Adhkar' : '🌙 زیکرەکانی ئێواران'),
          language == 'ar'
              ? 'حصّن نفسك وأهلك بأذكار المساء المأثورة عن النبي ﷺ'
              : (language == 'en'
                  ? 'Protect yourself and your family with the evening adhkar'
                  : 'ئێوارەکەت بە بەرەکەتی زیکرەکانی ئێواران و پاراستنی ماڵ و گیان بڕازێنەرەوە'),
          eveningTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'adhkar_channel',
              'زیکرەکان و ڕۆژی هەینی (Adhkar & Friday)',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      // 3. Bedtime & Surah Al-Mulk (10:30 PM / 22:30)
      if (bedtime) {
        var bedtimeTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 22, 30);
        if (bedtimeTime.isBefore(now)) {
          bedtimeTime = bedtimeTime.add(const Duration(days: 1));
        }
        await _notificationsPlugin.zonedSchedule(
          503,
          language == 'ar' ? '🌌 أذكار النوم وسورة الملك' : (language == 'en' ? '🌌 Bedtime Adhkar & Surah Al-Mulk' : '🌌 زیکرەکانی خەوتن و سوورەتی موڵک'),
          language == 'ar'
              ? 'تلاوة سورة الملك المنجية وأذكار النوم قبل المنام'
              : (language == 'en'
                  ? 'Recite Surah Al-Mulk, the protector from the grave, and sleep adhkar'
                  : 'سوورەتی موڵک و زیکرەکانی پێش خەوتن بخوێنە بۆ پارێزگاری لە سزای گۆڕ'),
          bedtimeTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'adhkar_channel',
              'زیکرەکان و ڕۆژی هەینی (Adhkar & Friday)',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      // 4. Friday Surah Al-Kahf (Friday 09:00 AM)
      if (friday) {
        var fridayTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
        while (fridayTime.weekday != DateTime.friday || fridayTime.isBefore(now)) {
          fridayTime = fridayTime.add(const Duration(days: 1));
        }
        await _notificationsPlugin.zonedSchedule(
          504,
          language == 'ar' ? '🕌 سنن يوم الجمعة وسورة الكهف' : (language == 'en' ? '🕌 Friday Sunnahs & Surah Al-Kahf' : '🕌 سوننەتەکانی ڕۆژی هەینی و سوورەتی کەهف'),
          language == 'ar'
              ? 'نورٌ ما بين الجمعتين: قراءة سورة الكهف والصلاة على النبي ﷺ'
              : (language == 'en'
                  ? 'A light between two Fridays: recite Surah Al-Kahf and send blessings upon the Prophet ﷺ'
                  : 'ڕووناکیی نێوان دوو هەینی: خوێندنەوەی سوورەتی کەهف و صەڵاواتدان لەسەر پێغەمبەر ﷺ'),
          fridayTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'adhkar_channel',
              'زیکرەکان و ڕۆژی هەینی (Adhkar & Friday)',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (e) {
      _logError(e);
    }
  }

  static Future<void> sendTestPrayerNotification({
    required String voiceId,
    required String language,
  }) async {
    if (!isSupportedPlatform) return;
    await schedulePrayerNotification(
      id: 9998,
      title: language == 'ar'
          ? '🕌 تجربة صوت الأذان'
          : (language == 'en' ? '🕌 Test Adhan Notification' : '🕌 تاقیکردنەوەی دەنگی بانگ'),
      body: language == 'ar'
          ? 'الله أكبر، هذا اختبار فوري لصوت الأذان'
          : (language == 'en'
              ? 'Allahu Akbar, this is a test notification for prayer sound'
              : 'الله أكبر، ئەمە تاقیکردنەوەی دەنگی بانگە'),
      scheduledDate: DateTime.now().add(const Duration(seconds: 3)),
      soundType: 'adhan',
      adhanVoice: voiceId,
      fajrAdhanVoice: voiceId,
      isFajr: voiceId.contains('fajr'),
    );
  }

  static Future<void> cancelAll() async {
    if (!isSupportedPlatform) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      _logError(e);
    }
  }
}
