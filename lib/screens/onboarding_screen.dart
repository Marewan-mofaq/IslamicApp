import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import '../models/city.dart';
import '../services/location_service.dart';
import '../main.dart';
import 'main_navigation.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _citySearchController = TextEditingController();
  int _currentPage = 0;
  String _selectedCityId = 'erbil';
  String _citySearchQuery = '';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _selectedCityId = settings.userCityId;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _citySearchController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_launch_done', true);
      // Save selected city
      await ref.read(settingsProvider.notifier).setUserCityId(_selectedCityId);
      // Request notification permissions
      await NotificationService.requestPermissions();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final lang = settings.language;
    final isRTL = lang == 'ku' || lang == 'ar';

    final stepNum = _currentPage + 1;
    final stepText = lang == 'ar'
        ? 'الخطوة $stepNum من 4'
        : (lang == 'en' ? 'Step $stepNum of 4' : 'هەنگاوی $stepNum لە 4');

    final skipText = lang == 'ar' ? 'تخطي' : (lang == 'en' ? 'Skip' : 'تێپەڕاندن');
    final nextBtnText = _currentPage == 3
        ? (lang == 'ar' ? 'بدء الاستخدام' : (lang == 'en' ? 'Get Started' : 'دەستپێکردنی ئەپ'))
        : (lang == 'ar' ? 'التالي' : (lang == 'en' ? 'Next' : 'داهاتوو'));

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            children: [
              // Top Bar: Step Indicator & Skip Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Step text
                    Text(
                      stepText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontFamily: 'Rabar',
                      ),
                    ),
                    if (_currentPage < 3)
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          skipText,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Rabar',
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // PageView Content: 4 Pages (1. Language, 2. Welcome, 3. City, 4. Notifications)
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildLanguagePage(theme, settings),
                    _buildWelcomePage(theme, settings),
                    _buildCityPage(theme, settings),
                    _buildNotificationsPage(theme, settings),
                  ],
                ),
              ),

              // Bottom Navigation: Indicator Dots & Next Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dots (4 total)
                    Row(
                      children: List.generate(4, (index) {
                        final isActive = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? theme.primaryColor : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    // Next / Get Started Button
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nextBtnText,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rabar',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == 3
                                ? Icons.check_circle_outline
                                : (isRTL ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━ PAGE 1: LANGUAGE SELECTION ━━━
  Widget _buildLanguagePage(AppThemePalette theme, SettingsState settings) {
    final lang = settings.language;

    final title = lang == 'ar'
        ? 'اختر لغة التطبيق 🌐'
        : (lang == 'en' ? 'Choose App Language 🌐' : 'زمانی ئەپەکە هەڵبژێرە 🌐');

    final subtitle = lang == 'ar'
        ? 'يرجى اختيار لغتك المفضلة، يمكنك تغييرها لاحقاً من الإعدادات'
        : (lang == 'en'
            ? 'Please choose your preferred language. You can change it anytime in settings.'
            : 'تکایە زمانی دڵخوازت دیاری بکە، دەتوانیت دواتریش لە ڕێکخستنەکان بیگۆڕیت.');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Emblem / Icon Container
          Center(
            child: Container(
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.12),
                border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Center(
                child: Text(
                  '🌍',
                  style: TextStyle(fontSize: 44),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Rabar',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withOpacity(0.65),
              fontFamily: 'Rabar',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // 1. Kurdish Option
          _buildLanguageOptionCard(
            theme: theme,
            code: 'ku',
            title: 'کوردی',
            subtitle: 'Kurdish - سۆرانی',
            flagEmoji: '☀️',
            isSelected: lang == 'ku',
            onTap: () {
              ref.read(settingsProvider.notifier).setLanguage('ku');
            },
          ),
          const SizedBox(height: 14),

          // 2. Arabic Option
          _buildLanguageOptionCard(
            theme: theme,
            code: 'ar',
            title: 'العربية',
            subtitle: 'Arabic - الفصحى',
            flagEmoji: '🕌',
            isSelected: lang == 'ar',
            onTap: () {
              ref.read(settingsProvider.notifier).setLanguage('ar');
            },
          ),
          const SizedBox(height: 14),

          // 3. English Option
          _buildLanguageOptionCard(
            theme: theme,
            code: 'en',
            title: 'English',
            subtitle: 'English Language',
            flagEmoji: '🌐',
            isSelected: lang == 'en',
            onTap: () {
              ref.read(settingsProvider.notifier).setLanguage('en');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOptionCard({
    required AppThemePalette theme,
    required String code,
    required String title,
    required String subtitle,
    required String flagEmoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.18) : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.white.withOpacity(0.08),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: theme.primaryColor.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            // Emoji / Flag badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.primaryColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.primaryColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Center(
                child: Text(
                  flagEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.primaryColor : Colors.white,
                      fontFamily: code == 'en' ? null : 'Rabar',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withOpacity(0.55),
                      fontFamily: code == 'en' ? null : 'Rabar',
                    ),
                  ),
                ],
              ),
            ),

            // Selection Radio / Checkmark
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? theme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? theme.primaryColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.black,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ━━━ PAGE 2: WELCOME & HIGHLIGHTS ━━━
  Widget _buildWelcomePage(AppThemePalette theme, SettingsState settings) {
    final lang = settings.language;

    final welcomeTitle = lang == 'ar'
        ? 'مرحباً بك في تطبيق إسلام'
        : (lang == 'en' ? 'Welcome to Islam App' : 'بەخێربێیت بۆ ئەپی ئیسلام');

    final welcomeSubtitle = lang == 'ar'
        ? 'رفيقك اليومي لمواقيت الصلاة، القرآن الكريم والأذكار'
        : (lang == 'en'
            ? 'Your daily companion for prayer times, Holy Quran, and Adhkar'
            : 'هاوەڵی پڕۆفیشناڵی ڕۆژانەت بۆ کاتەکانی بانگ، قورئانی پیرۆز و زیکرەکان');

    final f1Title = lang == 'ar'
        ? '١٠٠٪ يعمل بدون إنترنت'
        : (lang == 'en' ? '100% Offline Support' : '١٠٠٪ بەبێ ئینتەرنێت کاردەکات');
    final f1Sub = lang == 'ar'
        ? 'القرآن الكريم بالكامل والتفاسير والأذكار متاحة بدون إنترنت.'
        : (lang == 'en'
            ? 'Full Holy Quran, translations, and adhkar work completely offline.'
            : 'تەواوی قورئانی پیرۆز، تەفسیر و زیکرەکان ئۆفلاینن.');

    final f2Title = lang == 'ar'
        ? 'مواقيت الصلاة بدقة عالية'
        : (lang == 'en' ? 'Accurate Prayer Times' : 'کاتەکانی نوێژ بە پێوەری فەرمی');
    final f2Sub = lang == 'ar'
        ? 'حساب دقيق لمواقيت الصلاة والأذان بمختلف الطرق المعتمدة.'
        : (lang == 'en'
            ? 'Official prayer schedule with customizable calculation methods.'
            : 'بە خشتەی فەرمیی ئەوقافی شارەکانی هەرێمی کوردستان.');

    final f3Title = lang == 'ar'
        ? 'ودجات الشاشة والتحكم بالصوت'
        : (lang == 'en' ? 'Home Screen Widgets & Audio' : 'ویجێتی سەر شاشە و کۆنتڕۆڵی دەنگ');
    final f3Sub = lang == 'ar'
        ? 'مواقيت الصلاة على الشاشة الرئيسية والتحكم بالصوت أثناء القفل.'
        : (lang == 'en'
            ? 'Prayer times widgets and lock-screen Quran audio controls.'
            : 'کاتەکانی بانگ لەسەر شاشەی سەرەکی و کۆنتڕۆڵی قورئان لەسەر شاشەی قفڵ.');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Emblem / Icon Container
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withOpacity(0.12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 2),
            ),
            child: const Center(
              child: Text(
                '🕌',
                style: TextStyle(fontSize: 48),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'بِسمِ اللَّهِ الرَّحمٰنِ الرَّحيمِ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            welcomeTitle,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Rabar',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            welcomeSubtitle,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Rabar',
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Features List Cards
          _buildFeatureCard(
            theme: theme,
            icon: Icons.wifi_off_rounded,
            title: f1Title,
            subtitle: f1Sub,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            theme: theme,
            icon: Icons.access_time_rounded,
            title: f2Title,
            subtitle: f2Sub,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            theme: theme,
            icon: Icons.widgets_rounded,
            title: f3Title,
            subtitle: f3Sub,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required AppThemePalette theme,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Rabar',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                    fontFamily: 'Rabar',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━ PAGE 3: CITY SELECTION ━━━
  Widget _buildCityPage(AppThemePalette theme, SettingsState settings) {
    final citiesAsync = ref.watch(citiesFutureProvider);
    final lang = settings.language;

    final cityTitle = lang == 'ar'
        ? 'اختر مدينتك 📍'
        : (lang == 'en' ? 'Select Your City 📍' : 'شارەکەت هەڵبژێرە 📍');

    final citySub = lang == 'ar'
        ? 'لتحديد مواقيت الصلاة بدقة، يرجى اختيار مدينتك:'
        : (lang == 'en'
            ? 'To get accurate prayer times, please select your city:'
            : 'بۆ دیاریکردنی کاتی دروستی بانگەکان بەپێی خشتەی ئەوقاف شارەکەت هەڵبژێرە:');

    final gpsBtnText = lang == 'ar'
        ? 'تحديد المدينة تلقائياً عبر GPS'
        : (lang == 'en' ? 'Auto-detect City via GPS' : 'دیاریکردنی خۆکارانەی شار بە GPS');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cityTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Rabar',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            citySub,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Rabar',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // Auto-detect GPS button
          InkWell(
            onTap: () async {
              final cities = citiesAsync.value;
              if (cities == null || cities.isEmpty) return;
              final nearest = await LocationService.detectNearestCity(cities);
              if (nearest != null && mounted) {
                setState(() {
                  _selectedCityId = nearest.id;
                });
                _adaptCalculationMethod(nearest.country);
                final detectedName = lang == 'ar' ? nearest.ar : (lang == 'en' ? nearest.en : nearest.ku);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      lang == 'ar'
                          ? 'تم تحديد المدينة: $detectedName'
                          : (lang == 'en' ? 'City detected: $detectedName' : 'شاری نزیکت دیاریکرا: $detectedName'),
                      style: const TextStyle(fontFamily: 'Rabar'),
                    ),
                    backgroundColor: theme.primaryColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.primaryColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.my_location_rounded, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      gpsBtnText,
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Rabar',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _citySearchController,
              onChanged: (val) {
                setState(() {
                  _citySearchQuery = val.trim().toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: lang == 'ku'
                    ? 'گەڕان بۆ شار یان وڵات...'
                    : (lang == 'ar' ? 'ابحث عن المدينة أو الدولة...' : 'Search city or country...'),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontFamily: 'Rabar'),
                prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor, size: 20),
                suffixIcon: _citySearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () {
                          _citySearchController.clear();
                          setState(() {
                            _citySearchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: citiesAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: theme.primaryColor)),
              error: (_, __) => _buildFallbackCitiesList(theme, lang),
              data: (cities) {
                final filteredCities = _citySearchQuery.isEmpty
                    ? cities
                    : cities.where((c) {
                        final q = _citySearchQuery;
                        return c.ku.toLowerCase().contains(q) ||
                            c.ar.toLowerCase().contains(q) ||
                            c.en.toLowerCase().contains(q) ||
                            (c.countryKu.toLowerCase().contains(q)) ||
                            (c.countryAr?.toLowerCase().contains(q) ?? false) ||
                            (c.countryEn?.toLowerCase().contains(q) ?? false);
                      }).toList();

                if (filteredCities.isEmpty) {
                  return Center(
                    child: Text(
                      lang == 'ku' ? 'هیچ شارێک نەدۆزرایەوە' : (lang == 'ar' ? 'لم يتم العثور على مدينة' : 'No cities found'),
                      style: TextStyle(color: Colors.white54, fontFamily: 'Rabar'),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredCities.length,
                  itemBuilder: (context, index) {
                    final city = filteredCities[index];
                    final isSelected = _selectedCityId == city.id;
                    final displayName = lang == 'ar' ? city.ar : (lang == 'en' ? city.en : city.ku);
                    final countryName = lang == 'ar'
                        ? (city.countryAr ?? city.countryKu)
                        : (lang == 'en' ? (city.countryEn ?? city.country) : city.countryKu);
                    final flag = _getCountryFlag(city.country);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCityId = city.id;
                          });
                          _adaptCalculationMethod(city.country);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.primaryColor.withOpacity(0.18) : theme.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? theme.primaryColor : Colors.white.withOpacity(0.08),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(flag, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? theme.primaryColor : Colors.white,
                                        fontFamily: lang == 'en' ? null : 'Rabar',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      countryName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.5),
                                        fontFamily: lang == 'en' ? null : 'Rabar',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.primaryColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _adaptCalculationMethod(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code == 'IQ') {
      ref.read(settingsProvider.notifier).setCalculationMethod('KRG');
    } else if (['SA', 'AE', 'QA', 'KW', 'BH', 'OM'].contains(code)) {
      ref.read(settingsProvider.notifier).setCalculationMethod('UmmAlQura');
    } else if (['US', 'CA'].contains(code)) {
      ref.read(settingsProvider.notifier).setCalculationMethod('ISNA');
    } else if (code == 'TR') {
      ref.read(settingsProvider.notifier).setCalculationMethod('Diyanet');
    } else if (['PK', 'IN', 'BD', 'AF'].contains(code)) {
      ref.read(settingsProvider.notifier).setCalculationMethod('Karachi');
    } else if (['EG', 'JO', 'PS', 'SY', 'LB', 'YE', 'SD', 'MA', 'DZ', 'TN', 'LY'].contains(code)) {
      ref.read(settingsProvider.notifier).setCalculationMethod('Egyptian');
    } else {
      ref.read(settingsProvider.notifier).setCalculationMethod('MuslimWorldLeague');
    }
  }

  String _getCountryFlag(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'IQ':
        return '☀️';
      case 'SA':
        return '🇸🇦';
      case 'AE':
        return '🇦🇪';
      case 'QA':
        return '🇶🇦';
      case 'KW':
        return '🇰🇼';
      case 'BH':
        return '🇧🇭';
      case 'OM':
        return '🇴🇲';
      case 'TR':
        return '🇹🇷';
      case 'IR':
        return '🇮🇷';
      case 'SY':
        return '🇸🇾';
      case 'PS':
        return '🇵🇸';
      case 'JO':
        return '🇯🇴';
      case 'LB':
        return '🇱🇧';
      case 'EG':
        return '🇪🇬';
      case 'YE':
        return '🇾🇪';
      case 'SD':
        return '🇸🇩';
      case 'MA':
        return '🇲🇦';
      case 'DZ':
        return '🇩🇿';
      case 'TN':
        return '🇹🇳';
      case 'LY':
        return '🇱🇾';
      case 'DE':
        return '🇩🇪';
      case 'GB':
        return '🇬🇧';
      case 'SE':
        return '🇸🇪';
      case 'NO':
        return '🇳🇴';
      case 'DK':
        return '🇩🇰';
      case 'FI':
        return '🇫🇮';
      case 'NL':
        return '🇳🇱';
      case 'BE':
        return '🇧🇪';
      case 'FR':
        return '🇫🇷';
      case 'CH':
        return '🇨🇭';
      case 'AT':
        return '🇦🇹';
      case 'IT':
        return '🇮🇹';
      case 'ES':
        return '🇪🇸';
      case 'GR':
        return '🇬🇷';
      case 'US':
        return '🇺🇸';
      case 'CA':
        return '🇨🇦';
      case 'AU':
        return '🇦🇺';
      case 'PK':
        return '🇵🇰';
      case 'MY':
        return '🇲🇾';
      case 'ID':
        return '🇮🇩';
      default:
        return '🌍';
    }
  }

  Widget _buildFallbackCitiesList(AppThemePalette theme, String lang) {
    final fallbackList = [
      {'id': 'erbil', 'ku': 'هەولێر', 'ar': 'أربيل', 'en': 'Erbil'},
      {'id': 'sulaymaniyah', 'ku': 'سلێمانی', 'ar': 'السليمانية', 'en': 'Sulaymaniyah'},
      {'id': 'duhok', 'ku': 'دهۆک', 'ar': 'دهوك', 'en': 'Duhok'},
      {'id': 'kirkuk', 'ku': 'کەرکووک', 'ar': 'كركوك', 'en': 'Kirkuk'},
      {'id': 'halabja', 'ku': 'هەڵەبجە', 'ar': 'حلبجة', 'en': 'Halabja'},
      {'id': 'zakho', 'ku': 'زاخۆ', 'ar': 'زاخو', 'en': 'Zakho'},
      {'id': 'kalar', 'ku': 'کەلار / گەرمیان', 'ar': 'كلار', 'en': 'Kalar'},
      {'id': 'rania', 'ku': 'ڕانیە', 'ar': 'رانية', 'en': 'Rania'},
    ];

    return ListView.builder(
      itemCount: fallbackList.length,
      itemBuilder: (context, index) {
        final item = fallbackList[index];
        final isSelected = _selectedCityId == item['id'];
        final name = lang == 'ar' ? (item['ar'] ?? item['ku']!) : (lang == 'en' ? (item['en'] ?? item['ku']!) : item['ku']!);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedCityId = item['id']!;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? theme.primaryColor.withOpacity(0.18) : theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? theme.primaryColor : Colors.white10,
                ),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? theme.primaryColor : Colors.white,
                  fontFamily: lang == 'en' ? null : 'Rabar',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ━━━ PAGE 4: NOTIFICATIONS & COMPLETE ━━━
  Widget _buildNotificationsPage(AppThemePalette theme, SettingsState settings) {
    final lang = settings.language;

    final notifTitle = lang == 'ar'
        ? 'تنبيهات الأذان 🔔'
        : (lang == 'en' ? 'Prayer Notifications 🔔' : 'ئاگادارکردنەوەی بانگەکان 🔔');

    final notifSub = lang == 'ar'
        ? 'للتذكير بمواقيت الصلاة والأذان في وقتها، يرجى السماح بالإشعارات عند ظهور نافذة النظام.'
        : (lang == 'en'
            ? 'To receive timely adhan and prayer alerts, please allow notification permissions when prompted.'
            : 'بۆ ئەوەی لە کاتی خۆیدا بانگ بدات و ئاگادارت بکاتەوە لە کاتەکانی نوێژ، تکایە ڕێگە بە نۆتفکەیشن بدە لە کاتی دەرکەوتنی پەیامی سیستەمدا.');

    final tip1 = lang == 'ar'
        ? 'أذان الفجر والصلوات الأخرى بشكل منفصل'
        : (lang == 'en'
            ? 'Fajr and other prayers configured separately'
            : 'بانگی بەیانی و ٤ نوێژەکەی تر بە جیاواز');

    final tip2 = lang == 'ar'
        ? 'أذكار الصباح والمساء والنوم'
        : (lang == 'en'
            ? 'Morning, evening, and bedtime adhkar reminders'
            : 'زیکرەکانی بەیانیان، ئێواران و خەوتن');

    final tip3 = lang == 'ar'
        ? 'تعديل الأصوات في أي وقت من الإعدادات'
        : (lang == 'en'
            ? 'Customize adhan voices anytime in settings'
            : 'دەستکاریکردنی دەنگەکان لە هەر کاتێکدا لە ڕێکخستن');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withOpacity(0.12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.4), width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.notifications_active_rounded,
                size: 46,
                color: theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            notifTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Rabar',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            notifSub,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: Colors.white.withOpacity(0.75),
              fontFamily: 'Rabar',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Informative Tip Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: theme.primaryColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Rabar',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: theme.primaryColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip2,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Rabar',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: theme.primaryColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip3,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Rabar',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
