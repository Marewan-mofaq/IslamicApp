import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import 'adhan_playing_dialog.dart';

class BatteryOptimizationScreen extends ConsumerStatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  ConsumerState<BatteryOptimizationScreen> createState() => _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends ConsumerState<BatteryOptimizationScreen> {
  String _selectedBrand = 'samsung';

  Future<void> _openBatterySettings() async {
    final urisToTry = [
      Uri.parse('package:com.islamicapp.app.islamic_app_flutter'),
      Uri.parse('package:islamic_app_flutter'),
      Uri(scheme: 'package', path: 'com.islamicapp.app.islamic_app_flutter'),
    ];

    bool launched = false;
    for (final uri in urisToTry) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          launched = true;
          break;
        }
      } catch (_) {}
    }

    if (!launched && mounted) {
      final lang = ref.read(settingsProvider).language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'ar'
                ? 'يرجى الانتقال يدوياً إلى: إعدادات الموبايل > التطبيقات > التطبيق > البطارية'
                : (lang == 'en'
                    ? 'Please go manually to: Phone Settings > Apps > Islam App > Battery'
                    : 'تکایە بە دەستی بڕۆ بۆ: ڕێکخستنەکان (Settings) > بەرنامەکان (Apps) > ئەم ئەپە > پاتری (Battery)'),
            style: const TextStyle(fontFamily: 'Rabar'),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';
    final lang = settings.language;

    final title = lang == 'ar'
        ? '🔋 دقة الأذان وإعدادات البطارية'
        : (lang == 'en' ? '🔋 Battery & Adhan Accuracy' : '🔋 دڵنیابوون لە لێدانی بانگ و پاتری');

    final brands = [
      {'id': 'samsung', 'name': 'Samsung', 'icon': '📱'},
      {'id': 'xiaomi', 'name': 'Xiaomi / Redmi / POCO', 'icon': '⚡'},
      {'id': 'huawei', 'name': 'Huawei / Honor', 'icon': '🌸'},
      {'id': 'oppo', 'name': 'Oppo / Vivo / Realme', 'icon': '✨'},
      {'id': 'generic', 'name': lang == 'ar' ? 'أندرويد عام' : (lang == 'en' ? 'Other Android' : 'Android گشتی'), 'icon': '🤖'},
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontFamily: 'Rabar', fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor.withOpacity(0.18),
                      Theme.of(context).cardColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.primaryColor.withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.alarm_on, color: theme.primaryColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'ar'
                                ? 'لماذا تفعيل هذا الإعداد مهم؟'
                                : (lang == 'en' ? 'Why is this setting needed?' : 'بۆچی ئەم ڕێکخستنە گرنگە؟'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rabar',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lang == 'ar'
                                ? 'تقوم أنظمة أندرويد الحديثة بإيقاف التطبيقات في الخلفية لتوفير البطارية، مما قد يؤخر الأذان أو يمنعه خاصة في صلاة الفجر. تطبيق هذه الخطوات يضمن دقة الأذان ١٠٠٪.'
                                : (lang == 'en'
                                    ? 'Modern Android systems put background apps to sleep to save battery, which can silence or delay the Adhan alarm. Following these steps guarantees 100% on-time Adhan calls.'
                                    : 'سیستەمی ئەندرۆید بۆ پاراستنی پاتری ئەپەکان دەخەوێنێت، ئەمەش وادەکات دەنگی بانگی بەیانیان یان کاتەکانی تر لێنەدات. جێبەجێکردنی ئەم هەنگاوانە گەرەنتی لێدانی بانگ لەکاتی ١٠٠٪ی خۆیدا دەکات.'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              height: 1.5,
                              fontFamily: 'Rabar',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Text(
                lang == 'ar' ? 'اختر نوع هاتفك:' : (lang == 'en' ? 'Select your phone brand:' : 'جۆری مۆبایلەکەت دیاریبکە:'),
                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Rabar', fontSize: 14),
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: brands.map((b) {
                    final isSel = _selectedBrand == b['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Text(b['icon']!),
                        label: Text(
                          b['name']!,
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white,
                            fontFamily: 'Rabar',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: theme.primaryColor,
                        backgroundColor: Theme.of(context).cardColor,
                        onSelected: (_) => setState(() => _selectedBrand = b['id']!),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              _buildBrandGuide(context, _selectedBrand, lang, theme),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                ),
                onPressed: _openBatterySettings,
                icon: const Icon(Icons.settings, size: 22),
                label: Text(
                  lang == 'ar'
                      ? '⚙️ فتح إعدادات بطارية التطبيق'
                      : (lang == 'en' ? '⚙️ Open App Battery Settings' : '⚙️ کردنەوەی ڕێکخستنی پاتری ئەپ'),
                  style: const TextStyle(fontFamily: 'Rabar', fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  AdhanPlayingDialog.show(
                    context,
                    prayerName: 'Fajr',
                    voiceId: settings.selectedFajrAdhanVoice,
                    language: settings.language,
                    autoPlayAudio: true,
                  );
                },
                icon: const Icon(Icons.volume_up, size: 20),
                label: Text(
                  lang == 'ar'
                      ? '🔊 تجربة صوت الأذان الآن'
                      : (lang == 'en' ? '🔊 Test Adhan Sound Now' : '🔊 تاقیکردنەوەی دەنگی بانگ ئێستا'),
                  style: const TextStyle(fontFamily: 'Rabar', fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandGuide(BuildContext context, String brandId, String lang, AppThemePalette theme) {
    List<Map<String, String>> steps = [];

    if (brandId == 'samsung') {
      steps = [
        {
          'title': lang == 'ar' ? '١. البطارية غير المقيدة' : (lang == 'en' ? '1. Unrestricted Battery' : '١. پاتریی بێ سنوور (Unrestricted)'),
          'desc': lang == 'ar'
              ? 'اذهب إلى الإعدادات > التطبيقات > تطبيق الإسلام > البطارية > اختر "غير مقيد" (Unrestricted).'
              : (lang == 'en'
                  ? 'Go to Settings > Apps > Islam App > Battery > select "Unrestricted".'
                  : 'بڕۆ بۆ Settings > Apps > ئەم ئەپە > Battery > هەڵبژاردنی "Unrestricted" (بێ سنوور).'),
        },
        {
          'title': lang == 'ar' ? '٢. منع التطبيقات النائمة' : (lang == 'en' ? '2. Never Sleeping Apps' : '٢. دڵنیابوون لە نەخەوتنی ئەپ'),
          'desc': lang == 'ar'
              ? 'الإعدادات > العناية بالجهاز > البطارية > حدود الاستخدام في الخلفية > أضف التطبيق إلى "تطبيقات لا تنام أبداً" (Never sleeping apps).'
              : (lang == 'en'
                  ? 'Settings > Device care > Battery > Background usage limits > add to "Never sleeping apps".'
                  : 'بڕۆ بۆ Settings > Device care > Battery > Background usage limits > ئەپەکە بخەرە ناو "Never sleeping apps".'),
        },
      ];
    } else if (brandId == 'xiaomi') {
      steps = [
        {
          'title': lang == 'ar' ? '١. التشغيل التلقائي (Autostart)' : (lang == 'en' ? '1. Enable Autostart' : '١. چالاککردنی Autostart'),
          'desc': lang == 'ar'
              ? 'الإعدادات > التطبيقات > الأذونات > التشغيل التلقائي > فعّل التشغيل التلقائي لتطبيق الإسلام.'
              : (lang == 'en'
                  ? 'Settings > Apps > Permissions > Autostart > Enable Autostart for Islam App.'
                  : 'بڕۆ بۆ Settings > Apps > Permissions > Autostart > ئەم ئەپە چالاک بکە.'),
        },
        {
          'title': lang == 'ar' ? '٢. موفر البطارية (Battery Saver)' : (lang == 'en' ? '2. Battery Saver: No restrictions' : '٢. پاتری سەیڤەر بێ سنوور'),
          'desc': lang == 'ar'
              ? 'الإعدادات > التطبيقات > إدارة التطبيقات > تطبيق الإسلام > موفر البطارية > اختر "لا توجد قيود" (No restrictions).'
              : (lang == 'en'
                  ? 'Settings > Apps > Manage apps > Islam App > Battery saver > select "No restrictions".'
                  : 'بڕۆ بۆ Settings > Apps > Manage apps > ئەم ئەپە > Battery saver > هەڵبژاردنی "No restrictions".'),
        },
        {
          'title': lang == 'ar' ? '٣. قفل التطبيق في الرام' : (lang == 'en' ? '3. Lock App in Recent Apps' : '٣. قفڵکردنی ئەپ لە لیستی ئەپە کراوەکاندا'),
          'desc': lang == 'ar'
              ? 'افتح شاشة التطبيقات المفتوحة مؤخراً، اضغط مطولاً على التطبيق واضغط على أيقونة "القفل 🔒".'
              : (lang == 'en'
                  ? 'Open Recent Apps screen, long press on Islam App and tap the Lock 🔒 icon.'
                  : 'پەڕەی ئەپە کراوەکان بکەرەوە، دەست لەسەر ئەم ئەپە ڕابگرە و ئایکۆنی "قفڵ 🔒" دابگرە.'),
        },
      ];
    } else if (brandId == 'huawei') {
      steps = [
        {
          'title': lang == 'ar' ? '١. تشغيل التطبيق يدوياً' : (lang == 'en' ? '1. Manual App Launch' : '١. دەستپێکردنی دەستیی ئەپ'),
          'desc': lang == 'ar'
              ? 'الإعدادات > البطارية > تشغيل التطبيقات (App Launch) > أوقف التشغيل التلقائي للتطبيق وفعّل "التشغيل التلقائي والثانوي والعمل في الخلفية".'
              : (lang == 'en'
                  ? 'Settings > Battery > App Launch > switch to manual and enable "Auto-launch, Secondary launch & Run in background".'
                  : 'بڕۆ بۆ Settings > Battery > App launch > بۆ ئەم ئەپە هەڵبژاردنەکە بگۆڕە بۆ دستی و هەرسێ بژاردەی پاشبنەما چالاک بکە.'),
        },
      ];
    } else if (brandId == 'oppo') {
      steps = [
        {
          'title': lang == 'ar' ? '١. السماح بالنشاط في الخلفية' : (lang == 'en' ? '1. Allow Background Activity' : '١. ڕێگەدان بە چالاکی لە پاشبنەما'),
          'desc': lang == 'ar'
              ? 'الإعدادات > البطارية > استخدام بطارية التطبيق > اختر "السماح بالنشاط في الخلفية والسماح بالبدء التلقائي".'
              : (lang == 'en'
                  ? 'Settings > Battery > App Battery Usage > select "Allow background activity & Allow auto-launch".'
                  : 'بڕۆ بۆ Settings > Battery > App battery usage > هەڵبژاردنی "Allow background activity".'),
        },
      ];
    } else {
      steps = [
        {
          'title': lang == 'ar' ? '١. تحسين البطارية' : (lang == 'en' ? '1. Battery Optimization' : '١. پاتری ئۆپتیمایزەیشن (Battery Optimization)'),
          'desc': lang == 'ar'
              ? 'الإعدادات > التطبيقات > تطبيق الإسلام > البطارية > اختر "غير مقيد" (Unrestricted) أو لا يتم التحسين.'
              : (lang == 'en'
                  ? 'Settings > Apps > Islam App > Battery > select "Unrestricted" (Not optimized).'
                  : 'بڕۆ بۆ Settings > Apps > ئەم ئەپە > Battery > هەڵبژاردنی "Unrestricted" یان "Not optimized".'),
        },
        {
          'title': lang == 'ar' ? '٢. السماح بالمنبهات الدقيقة' : (lang == 'en' ? '2. Allow Exact Alarms' : '٢. مۆڵەتی زەنگی تەواو (Exact Alarms)'),
          'desc': lang == 'ar'
              ? 'الإعدادات > التطبيقات > الوصول الخاص > المنبهات والتذكيرات > تأكد من تفعيل "السماح بضبط المنبهات الدقيقة".'
              : (lang == 'en'
                  ? 'Settings > Apps > Special app access > Alarms & reminders > Ensure "Allow setting alarms" is On.'
                  : 'بڕۆ بۆ Settings > Apps > Special app access > Alarms & reminders > دڵنیابە مۆڵەتی زەنگ چالاک کراوە.'),
        },
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.map((s) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['title']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Rabar',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['desc']!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12.5,
                          height: 1.5,
                          fontFamily: 'Rabar',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
