import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../main.dart'; // to read citiesFutureProvider
import 'adhan_settings_screen.dart';
import '../services/location_service.dart';
import '../widgets/city_selector_sheet.dart';
import '../models/city.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final citiesAsync = ref.watch(citiesFutureProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    // Localized labels
    final title = settings.language == 'ku' ? 'ڕێکخستنەکان' : settings.language == 'ar' ? 'الإعدادات' : 'Settings';
    final sectionGeneral = settings.language == 'ku' ? 'گشتی' : settings.language == 'ar' ? 'عام' : 'General';
    final labelLanguage = settings.language == 'ku' ? 'زمان' : settings.language == 'ar' ? 'اللغة' : 'Language';
    final labelTheme = settings.language == 'ku' ? 'تێم و ڕەنگ' : settings.language == 'ar' ? 'المظهر واللون' : 'Theme Preset';
    final labelCity = settings.language == 'ku' ? 'شار' : settings.language == 'ar' ? 'المدينة' : 'Active City';
    final labelAdhan = settings.language == 'ku' ? 'ئاگادارکردنەوەی بانگ' : settings.language == 'ar' ? 'تنبيهات الأذان' : 'Adhan Notifications';
    final sectionPrayer = settings.language == 'ku' ? 'ڕێکخستنی کاتەکانی نوێژ' : settings.language == 'ar' ? 'حسابات الصلاة' : 'Prayer Settings';
    final labelMethod = settings.language == 'ku' ? 'ڕێگای ئەژمارکردن' : settings.language == 'ar' ? 'طريقة الحساب' : 'Calculation Method';
    final labelMadhab = settings.language == 'ku' ? 'مەزهەبی عەسر' : settings.language == 'ar' ? 'مذهب العصر' : 'Asr Madhab';
    
    final sectionOffsets = settings.language == 'ku' ? 'چاکسازی خولەکەکان (جیاوازی کات)' : settings.language == 'ar' ? 'تعديل الدقائق يدوياً' : 'Manual Minute Adjustments';

    final themes = {
      'emerald': settings.language == 'ku' ? 'سەوزی زومڕەت' : settings.language == 'ar' ? 'الأخضر الزمردي' : 'Emerald Green',
      'sepia': settings.language == 'ku' ? 'قاوەیی خۆڵەمێشی' : settings.language == 'ar' ? 'البني الدافئ' : 'Warm Sepia',
      'midnight': settings.language == 'ku' ? 'شینی تاریک' : settings.language == 'ar' ? 'الأزرق الداكن' : 'Midnight Blue',
      'royal': settings.language == 'ku' ? 'مۆری شاهانە' : settings.language == 'ar' ? 'البنفسجي الملكي' : 'Royal Purple',
    };

    final methods = {
      'KRG': settings.language == 'ku' ? 'وەزارەتی ئەوقافی کوردستان / Diyanet' : settings.language == 'ar' ? 'وزارة الأوقاف الكردستانية / Diyanet' : 'KRG Endowments / Diyanet',
      'MuslimWorldLeague': 'Muslim World League (MWL)',
      'UmmAlQura': 'Umm Al-Qura University, Makkah',
      'Egyptian': 'Egyptian General Authority of Survey',
      'Karachi': 'University of Islamic Sciences, Karachi',
      'ISNA': 'Islamic Society of North America (ISNA)',
    };

    final madhabs = {
      'Shafi': settings.language == 'ku' ? 'شافعی (جمهور)' : settings.language == 'ar' ? 'الشافعي (الجمهور)' : 'Standard (Shafi, Maliki, Hanbali)',
      'Hanafi': settings.language == 'ku' ? 'حەنەفی' : settings.language == 'ar' ? 'الحنفي' : 'Hanafi Madhab',
    };

    final prayerNames = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayerNamesLocalized = {
      'Fajr': { 'ku': 'فەجر', 'ar': 'الفجر', 'en': 'Fajr' },
      'Sunrise': { 'ku': 'ڕۆژهەڵات', 'ar': 'الشروق', 'en': 'Sunrise' },
      'Dhuhr': { 'ku': 'زوهر', 'ar': 'الظهر', 'en': 'Dhuhr' },
      'Asr': { 'ku': 'عەسر', 'ar': 'العصر', 'en': 'Asr' },
      'Maghrib': { 'ku': 'مەغریب', 'ar': 'المغرب', 'en': 'Maghrib' },
      'Isha': { 'ku': 'عیشا', 'ar': 'العشاء', 'en': 'Isha' },
    };
    final langKey = settings.language == 'ar' ? 'ar' : settings.language == 'en' ? 'en' : 'ku';

    return Scaffold(
      backgroundColor: settings.palette.backgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. GENERAL SECTION
              _buildSectionHeader(context, sectionGeneral),
              
              // Language Selector
              _buildSettingCard(
                context,
                title: labelLanguage,
                value: settings.language == 'ku' ? 'کوردی' : settings.language == 'ar' ? 'العربية' : 'English',
                icon: Icons.translate,
                onTap: () {
                  _showLanguageSelector(context, ref, settings.language);
                },
              ),

              // Theme Selector
              _buildSettingCard(
                context,
                title: labelTheme,
                value: settings.language == 'en' ? settings.palette.nameEn : settings.language == 'ar' ? settings.palette.nameAr : settings.palette.nameKu,
                icon: Icons.palette_outlined,
                onTap: () {
                  _showThemeSelector(context, ref, settings.themeName);
                },
              ),

              // Adhan Notification Settings
              _buildSettingCard(
                context,
                title: labelAdhan,
                value: settings.notificationSound == 'silent'
                    ? (settings.language == 'ku' ? 'بێدەنگ' : settings.language == 'ar' ? 'صامت' : 'Silent')
                    : settings.notificationSound == 'bell'
                        ? (settings.language == 'ku' ? 'زەنگ' : settings.language == 'ar' ? 'رنة' : 'Bell')
                        : (settings.language == 'ku' ? 'بانگ' : settings.language == 'ar' ? 'الأذان' : 'Adhan'),
                icon: Icons.notifications_active_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdhanSettingsScreen()),
                  );
                },
              ),

              // City Selector
              citiesAsync.when(
                loading: () => SizedBox(),
                error: (err, stack) => SizedBox(),
                data: (citiesList) {
                  final activeCity = citiesList.firstWhere(
                    (c) => c.id == settings.userCityId,
                    orElse: () => citiesList.first,
                  );
                  final cityName = settings.language == 'ar'
                      ? activeCity.ar
                      : settings.language == 'en'
                      ? activeCity.en
                      : activeCity.ku;

                  return _buildSettingCard(
                    context,
                    title: labelCity,
                    value: cityName,
                    icon: Icons.location_on_outlined,
                    onTap: () {
                      _showCitySelector(context, ref, citiesList, settings.userCityId, settings.language);
                    },
                  );
                },
              ),

              // GPS Auto-detect Location Switch
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    secondary: Icon(Icons.my_location_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                    title: Text(
                      settings.language == 'ku'
                          ? 'دیاریکردنی خۆکارانەی شوێن بە GPS'
                          : settings.language == 'ar'
                              ? 'تحديد الموقع تلقائياً عبر GPS'
                              : 'Auto-detect Location via GPS',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      settings.language == 'ku'
                          ? 'گۆڕینی کاتەکانی بانگ بەپێی شوێنی ئێستای مۆبایلەکەت'
                          : settings.language == 'ar'
                              ? 'تحديث أوقات الصلاة بناءً على موقع الجهاز'
                              : 'Update prayer times based on current device location',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                    ),
                    value: settings.useGPS,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) async {
                      await ref.read(settingsProvider.notifier).setUseGPS(val);
                      if (val) {
                        final cities = citiesAsync.value;
                        if (cities != null && cities.isNotEmpty) {
                          final nearest = await LocationService.detectNearestCity(cities);
                          if (nearest != null) {
                            await ref.read(settingsProvider.notifier).setUserCityId(nearest.id);
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
                          }
                        }
                      }
                    },
                  ),
                ),
              ),



              SizedBox(height: 24),

              // 3. MINUTE OFFSETS ADJUSTMENTS
              _buildSectionHeader(context, sectionOffsets),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Column(
                  children: prayerNames.map((pName) {
                    final currentOffset = settings.prayerOffsets[pName] ?? 0;
                    final pLocalizedName = prayerNamesLocalized[pName]?[langKey] ?? pName;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            pLocalizedName,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.primary),
                                onPressed: () {
                                  final copy = Map<String, int>.from(settings.prayerOffsets);
                                  copy[pName] = (copy[pName] ?? 0) - 1;
                                  ref.read(settingsProvider.notifier).setPrayerOffsets(copy);
                                },
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                child: Text(
                                  '${currentOffset > 0 ? "+" : ""}$currentOffset',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                                onPressed: () {
                                  final copy = Map<String, int>.from(settings.prayerOffsets);
                                  copy[pName] = (copy[pName] ?? 0) + 1;
                                  ref.read(settingsProvider.notifier).setPrayerOffsets(copy);
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4, right: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: Colors.white.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }

  // --- SELECTOR BOTTOM SHEETS ---

  void _showLanguageSelector(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('کوردی'),
              trailing: current == 'ku' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setLanguage('ku');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('العربية'),
              trailing: current == 'ar' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setLanguage('ar');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('English'),
              trailing: current == 'en' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setLanguage('en');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context, WidgetRef ref, String current) {
    final settings = ref.read(settingsProvider);
    final lang = settings.language;

    showModalBottomSheet(
      context: context,
      backgroundColor: settings.palette.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemePalette.themes.map((theme) {
            final isSelected = current == theme.id;
            final themeName = lang == 'en' ? theme.nameEn : lang == 'ar' ? theme.nameAr : theme.nameKu;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.primaryColor,
                radius: 14,
              ),
              title: Text(
                themeName,
                style: TextStyle(
                  color: isSelected ? theme.primaryColor : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Rabar',
                ),
              ),
              trailing: isSelected ? Icon(Icons.check, color: theme.primaryColor) : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setThemeName(theme.id);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showMethodSelector(BuildContext context, WidgetRef ref, String current, Map<String, String> methods) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: methods.entries.map((entry) {
            return ListTile(
              title: Text(entry.key),
              subtitle: Text(entry.value, style: TextStyle(fontSize: 11)),
              trailing: current == entry.key ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setCalculationMethod(entry.key);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showMadhabSelector(BuildContext context, WidgetRef ref, String current, Map<String, String> madhabs) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: madhabs.entries.map((entry) {
            return ListTile(
              title: Text(entry.value),
              trailing: current == entry.key ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setAsrMadhab(entry.key);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
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
}

