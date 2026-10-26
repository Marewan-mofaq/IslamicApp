import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../widgets/bouncing_button.dart';
import 'adhan_playing_dialog.dart';

class AdhanSettingsScreen extends ConsumerStatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  ConsumerState<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends ConsumerState<AdhanSettingsScreen> {
  late AudioPlayer _audioPlayer;
  StreamSubscription? _playerStateSubscription;
  String? _currentlyPlayingVoiceId;
  bool _isPlaying = false;

  bool _morningNotif = true;
  bool _eveningNotif = true;
  bool _bedtimeNotif = true;
  bool _fridayNotif = true;

  final List<Map<String, String>> adhanVoices = [
    {
      'id': 'nasser',
      'name_ku': 'بانگی ناسر ئەلقەتامی',
      'name_ar': 'أذان ناصر القطامي',
      'name_en': 'Nasser Al-Qatami Adhan',
      'icon': '🕋',
      'asset': 'audio/adhan/nasser.mp3',
      'url': 'https://www.islamcan.com/audio/adhan/azan5.mp3',
    },
    {
      'id': 'ahmed',
      'name_ku': 'بانگی ئەحمەد ئەلعیمادی',
      'name_ar': 'أذان أحمد العمادي',
      'name_en': 'Ahmed Al-Imadi Adhan',
      'icon': '🌙',
      'asset': 'audio/adhan/ahmed.mp3',
      'url': 'https://www.islamcan.com/audio/adhan/azan3.mp3',
    },
    {
      'id': 'majed',
      'name_ku': 'بانگی ماجد ئەلحەمەسانی',
      'name_ar': 'أذان ماجد الحمثاني',
      'name_en': 'Majed Al-Hamathani Adhan',
      'icon': '⭐',
      'asset': 'audio/adhan/majed.mp3',
      'url': 'https://www.islamcan.com/audio/adhan/azan2.mp3',
    },
    {
      'id': 'mokhtar',
      'name_ku': 'بانگی مختار حاج سلیمان',
      'name_ar': 'أذان مختار حاج سليمان',
      'name_en': 'Mokhtar Hadj Slimane Adhan',
      'icon': '✨',
      'asset': 'audio/adhan/mokhtar.mp3',
      'url': 'https://www.islamcan.com/audio/adhan/azan4.mp3',
    },
  ];

  final List<Map<String, String>> fajrAdhanVoices = [
    {
      'id': 'mishary_fajr',
      'name_ku': 'مشاری ڕاشید ئەلعەفاسی',
      'name_ar': 'مشاري راشد العفاسي',
      'name_en': 'Mishary Rashid Alafasy',
      'icon': '🌅',
      'asset': 'audio/adhan/mishary_fajr.mp3',
      'url': '',
    },
    {
      'id': 'makkah_fajr',
      'name_ku': 'حەرەمی مەککەی پیرۆز',
      'name_ar': 'المسجد الحرام بمكة',
      'name_en': 'Masjid Al-Haram Makkah',
      'icon': '🕋',
      'asset': 'audio/adhan/makkah_fajr.mp3',
      'url': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAdhkarNotifSettings();
    _audioPlayer = AudioPlayer();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  Future<void> _loadAdhkarNotifSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _morningNotif = prefs.getBool('notif_adhkar_morning') ?? true;
          _eveningNotif = prefs.getBool('notif_adhkar_evening') ?? true;
          _bedtimeNotif = prefs.getBool('notif_adhkar_bedtime') ?? true;
          _fridayNotif = prefs.getBool('notif_adhkar_friday') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateAdhkarNotif(String key, bool val) async {
    setState(() {
      if (key == 'morning') _morningNotif = val;
      if (key == 'evening') _eveningNotif = val;
      if (key == 'bedtime') _bedtimeNotif = val;
      if (key == 'friday') _fridayNotif = val;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_adhkar_$key', val);
      final lang = ref.read(settingsProvider).language;
      await NotificationService.scheduleDailyAdhkarNotifications(
        language: lang,
        morning: _morningNotif,
        evening: _eveningNotif,
        bedtime: _bedtimeNotif,
        friday: _fridayNotif,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _disposeAudioPlayer();
    super.dispose();
  }

  Future<void> _disposeAudioPlayer() async {
    await _audioPlayer.stop();
    _audioPlayer.dispose();
  }

  Future<void> _togglePlayPreview(Map<String, String> voice) async {
    final voiceId = voice['id']!;
    final assetPath = voice['asset']!;
    final url = voice['url']!;

    if (_currentlyPlayingVoiceId == voiceId && _isPlaying) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingVoiceId = null;
        });
      }
      return;
    }

    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _currentlyPlayingVoiceId = voiceId;
          _isPlaying = true;
        });
      }

      // Check if the asset is bundled in the current build
      bool assetLoaded = false;
      try {
        await rootBundle.load('assets/$assetPath');
        assetLoaded = true;
      } catch (_) {
        assetLoaded = false;
      }

      if (!mounted) return;

      if (assetLoaded) {
        try {
          await _audioPlayer.play(AssetSource(assetPath));
        } catch (_) {
          if (!mounted) return;
          if (url.isNotEmpty) {
            await _audioPlayer.play(UrlSource(url));
          }
        }
      } else {
        // Fallback for older builds where mishary_fajr is not yet bundled
        bool playedFallback = false;
        if (voiceId == 'mishary_fajr') {
          try {
            await rootBundle.load('assets/audio/adhan/mishary.mp3');
            if (!mounted) return;
            await _audioPlayer.play(AssetSource('audio/adhan/mishary.mp3'));
            playedFallback = true;
          } catch (_) {}
        }
        if (!mounted) return;
        if (!playedFallback && url.isNotEmpty) {
          await _audioPlayer.play(UrlSource(url));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingVoiceId = null;
        });
      }
      if (mounted) {
        final lang = ref.read(settingsProvider).language;
        final errorMsg = lang == 'ku'
            ? 'کێشەیەک ڕوویدا لە کاتی پەخشکردنی دەنگی بانگدا'
            : lang == 'ar'
                ? 'حدث خطأ أثناء تشغيل صوت الأذان'
                : 'An error occurred while playing the adhan audio';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku' ? 'ئاگادارکردنەوەی بانگ' : settings.language == 'ar' ? 'تنبيهات الأذان' : 'Adhan Notifications';
    final sectionSound = settings.language == 'ku' ? 'جۆری دەنگی ئاگادارکردنەوە' : settings.language == 'ar' ? 'نوع التنبيه' : 'Notification Sound';
    final sectionVoices = settings.language == 'ku'
        ? 'دەنگی بانگبێژ'
        : settings.language == 'ar'
            ? 'صوت المؤذن'
            : 'Adhan Reciter Voice';
    final fajrAdhanNote = settings.language == 'ku'
        ? 'تێبینی: بانگی شێخ مشاری ڕاشد عەفاسی تەنیا لە کاتی نوێژی بەیانی (الصلاة خير من النوم) پەخش دەکرێت.'
        : settings.language == 'ar'
            ? 'ملاحظة: أذان الشيخ مشاري راشد العفاسي مخصص حصرياً لوقت صلاة الفجر (الصلاة خير من النوم).'
            : 'Note: Sheikh Mishary Rashid Alafasy adhan is exclusively played at Fajr prayer time (with As-Salatu Khayrun Min An-Nawm).';
    final sectionPrayers = settings.language == 'ku' ? 'ئاگادارکردنەوەی نوێژەکان' : settings.language == 'ar' ? 'تفعيل تنبيهات الصلوات' : 'Active Prayer Alerts';

    final soundOptions = {
      'silent': settings.language == 'ku' ? 'بێدەنگ' : settings.language == 'ar' ? 'صامت' : 'Silent',
      'bell': settings.language == 'ku' ? 'زەنگ' : settings.language == 'ar' ? 'رنة قصيرة' : 'Short Bell',
      'adhan': settings.language == 'ku' ? 'بانگی تەواو' : settings.language == 'ar' ? 'الأذان الكامل' : 'Full Adhan Recitation',
    };

    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayerNamesLocalized = {
      'Fajr': { 'ku': 'بەیانی', 'ar': 'الفجر', 'en': 'Fajr' },
      'Dhuhr': { 'ku': 'نیوەڕۆ', 'ar': 'الظهر', 'en': 'Dhuhr' },
      'Asr': { 'ku': 'عەسڕ', 'ar': 'العصر', 'en': 'Asr' },
      'Maghrib': { 'ku': 'مەغریب', 'ar': 'المغرب', 'en': 'Maghrib' },
      'Isha': { 'ku': 'عیشا', 'ar': 'العشاء', 'en': 'Isha' },
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Rabar')),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(isRTL ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // 1. NOTIFICATION SOUND TYPE
            _buildSectionHeader(sectionSound, Theme.of(context).colorScheme.primary),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Material(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: soundOptions.entries.map((entry) {
                      return RadioListTile<String>(
                        value: entry.key,
                        groupValue: settings.notificationSound,
                        activeColor: Theme.of(context).colorScheme.primary,
                        title: Text(
                          entry.value,
                          style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Rabar'),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(settingsProvider.notifier).setNotificationSound(val);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            // 2. ADHAN RECITER VOICES (if Full Adhan is selected)
            if (settings.notificationSound == 'adhan') ...[
              _buildSectionHeader(
                settings.language == 'ku'
                    ? 'دەنگی بانگبێژ (نوێژەکانی تر)'
                    : settings.language == 'ar'
                        ? 'صوت المؤذن (باقي الصلوات)'
                        : 'Adhan Reciter (Regular Prayers)',
                Theme.of(context).colorScheme.primary,
              ),
              ...adhanVoices.map((v) {
                final isSelected = settings.selectedAdhanVoice == v['id'];
                final isCurrentPlaying = _currentlyPlayingVoiceId == v['id'] && _isPlaying;
                final voiceName = settings.language == 'ku'
                    ? v['name_ku']
                    : settings.language == 'ar'
                        ? v['name_ar']
                        : v['name_en'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                          : Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                        : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: () {
                        ref.read(settingsProvider.notifier).setSelectedAdhanVoice(v['id']!);
                      },
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        child: Text(v['icon'] ?? '🕌', style: const TextStyle(fontSize: 16)),
                      ),
                      title: Text(
                        voiceName ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Rabar',
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isCurrentPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        onPressed: () => _togglePlayPreview(v),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              // FAJR RECITER VOICES (with "الصلاة خير من النوم")
              _buildSectionHeader(
                settings.language == 'ku'
                    ? 'دەنگی بانگی بەیانی (الصلاة خير من النوم)'
                    : settings.language == 'ar'
                        ? 'صوت أذان الفجر (الصلاة خير من النوم)'
                        : 'Fajr Adhan Voice (with Special Formula)',
                Theme.of(context).colorScheme.primary,
              ),
              ...fajrAdhanVoices.map((v) {
                final isSelected = settings.selectedFajrAdhanVoice == v['id'];
                final isCurrentPlaying = _currentlyPlayingVoiceId == v['id'] && _isPlaying;
                final voiceName = settings.language == 'ku'
                    ? v['name_ku']
                    : settings.language == 'ar'
                        ? v['name_ar']
                        : v['name_en'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                          : Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                        : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: () {
                        ref.read(settingsProvider.notifier).setSelectedFajrAdhanVoice(v['id']!);
                      },
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        child: Text(v['icon'] ?? '🌅', style: const TextStyle(fontSize: 16)),
                      ),
                      title: Text(
                        voiceName ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Rabar',
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isCurrentPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        onPressed: () => _togglePlayPreview(v),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
              // Test Adhan Screen Button
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: double.infinity,
                child: BouncingButton(
                  onTap: () {
                    AdhanPlayingDialog.show(
                      context,
                      prayerName: 'Dhuhr',
                      voiceId: settings.selectedAdhanVoice,
                      language: settings.language,
                      autoPlayAudio: true,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_active_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            settings.language == 'ku'
                                ? 'تاقیکردنەوەی شاشەی کاتی بانگدان و دوگمەی ڕاگرتن'
                                : settings.language == 'ar'
                                    ? 'تجربة شاشة وقت الأذان وزر الإيقاف'
                                    : 'Preview Adhan Screen & Stop Button',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Rabar',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Direct Test Notification Button with Sound (Plays real notification after 3s)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: double.infinity,
                child: BouncingButton(
                  onTap: () async {
                    await NotificationService.sendTestPrayerNotification(
                      voiceId: settings.selectedAdhanVoice,
                      language: settings.language,
                    );
                    if (context.mounted) {
                      final snackText = settings.language == 'ku'
                          ? '🔔 نۆتفیکەیشنەکە پاش ٣ چرکە دێت. دەتوانیت شاشەی مۆبایلەکە قفڵ بکەیت تا دەنگەکەی ببیستیت.'
                          : settings.language == 'ar'
                              ? '🔔 سيصل الإشعار بعد ٣ ثوانٍ. يمكنك قفل الشاشة لسماع الصوت.'
                              : '🔔 Test notification will arrive in 3s. You can lock your screen to hear it.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(snackText, style: const TextStyle(fontFamily: 'Rabar')),
                          backgroundColor: const Color(0xFF131822),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.85),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up_rounded, color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            settings.language == 'ku'
                                ? 'تاقیکردنەوەی نۆتفیکەیشنی دەنگی بانگ (پاش ٣ چرکە)'
                                : settings.language == 'ar'
                                    ? 'تجربة إشعار صوت الأذان الفعلي (بعد ٣ ثوانٍ)'
                                    : 'Test Real Adhan Notification Sound (3s)',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Rabar',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. PRAYER SPECIFIC TOGGLES
            _buildSectionHeader(sectionPrayers, Theme.of(context).colorScheme.primary),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Material(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: prayerNames.map((p) {
                    final isAlertActive = settings.prayerNotifications[p] ?? true;
                    final pName = prayerNamesLocalized[p]?[settings.language] ?? p;

                    return SwitchListTile(
                      activeColor: Theme.of(context).colorScheme.primary,
                      value: isAlertActive,
                      title: Text(
                        pName,
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                      ),
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).setPrayerNotification(p, val);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. SMART ADHKAR & FRIDAY REMINDERS
            _buildSectionHeader(
              settings.language == 'ar'
                  ? 'أذكار الصباح والمساء والجمعة'
                  : (settings.language == 'en' ? 'Smart Adhkar & Friday Reminders' : 'ئاگادارکردنەوەی زیکرەکان و ڕۆژی هەینی'),
              Theme.of(context).colorScheme.primary,
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Material(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: Theme.of(context).colorScheme.primary,
                      value: _morningNotif,
                      title: Text(
                        settings.language == 'ar'
                            ? '🌅 أذكار الصباح (من الفجر إلى العصر)'
                            : (settings.language == 'en' ? '🌅 Morning Adhkar (Fajr to Asr)' : '🌅 زیکرەکانی بەیانیان (لە بەیانی تا عەسر)'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                      ),
                      subtitle: Text(
                        settings.language == 'ar'
                            ? 'تذكير يومي بقراءة أذكار الصباح بعد صلاة الفجر'
                            : (settings.language == 'en' ? 'Daily morning remembrance reminder' : 'بیرخستنەوەی ڕۆژانەی ئەزکارەکانی بەیانی لە نێوان بانگی بەیانی تا عەسر'),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'Rabar'),
                      ),
                      onChanged: (val) => _updateAdhkarNotif('morning', val),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    SwitchListTile(
                      activeColor: Theme.of(context).colorScheme.primary,
                      value: _eveningNotif,
                      title: Text(
                        settings.language == 'ar'
                            ? '🌙 أذكار المساء (من العصر إلى العشاء)'
                            : (settings.language == 'en' ? '🌙 Evening Adhkar (Asr to Isha)' : '🌙 زیکرەکانی ئێواران (لە عەسر تا عیشا)'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                      ),
                      subtitle: Text(
                        settings.language == 'ar'
                            ? 'تذكير يومي بقراءة أذكار المساء بعد صلاة العصر'
                            : (settings.language == 'en' ? 'Daily evening remembrance reminder' : 'بیرخستنەوەی ڕۆژانەی ئەزکارەکانی ئێوارە لە نێوان بانگی عەسر تا عیشا'),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'Rabar'),
                      ),
                      onChanged: (val) => _updateAdhkarNotif('evening', val),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    SwitchListTile(
                      activeColor: Theme.of(context).colorScheme.primary,
                      value: _bedtimeNotif,
                      title: Text(
                        settings.language == 'ar'
                            ? '🌌 أذكار النوم وسورة الملك (من العشاء إلى الفجر)'
                            : (settings.language == 'en' ? '🌌 Bedtime Adhkar & Surah Al-Mulk (Isha to Fajr)' : '🌌 زیکرەکانی خەوتن و سوورەتی موڵک (لە عیشا تا بەیانی)'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                      ),
                      subtitle: Text(
                        settings.language == 'ar'
                            ? 'تذكير بقراءة سورة الملك وأذكار النوم بعد صلاة العشاء'
                            : (settings.language == 'en' ? 'Reminder for Surah Al-Mulk & sleep adhkar' : 'بیرخستنەوەی خوێندنەوەی سوورەتی موڵک و ئەزکاری خەوتن لە نێوان بانگی عیشا تا بەیانی'),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'Rabar'),
                      ),
                      onChanged: (val) => _updateAdhkarNotif('bedtime', val),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    SwitchListTile(
                      activeColor: Theme.of(context).colorScheme.primary,
                      value: _fridayNotif,
                      title: Text(
                        settings.language == 'ar'
                            ? '🕌 سورة الكهف يوم الجمعة (٠٩:٠٠ ص)'
                            : (settings.language == 'en' ? '🕌 Friday Surah Al-Kahf (09:00 AM)' : '🕌 سوورەتی کەهف لە ڕۆژی هەینیدا (٠٩:٠٠)'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                      ),
                      subtitle: Text(
                        settings.language == 'ar'
                            ? 'تذكير بسنن الجمعة وقراءة سورة الكهف'
                            : (settings.language == 'en' ? 'Friday Sunnahs & Surah Al-Kahf reminder' : 'بیرخستنەوەی سوننەتەکانی هەینی و کەهف'),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'Rabar'),
                      ),
                      onChanged: (val) => _updateAdhkarNotif('friday', val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: accentColor,
          letterSpacing: 0.5,
          fontFamily: 'Rabar',
        ),
      ),
    );
  }
}
