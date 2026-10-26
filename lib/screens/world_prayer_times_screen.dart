import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/city.dart';
import '../providers/settings_provider.dart';
import '../services/prayer_service.dart';

class WorldPrayerTimesScreen extends ConsumerStatefulWidget {
  const WorldPrayerTimesScreen({super.key});

  @override
  ConsumerState<WorldPrayerTimesScreen> createState() => _WorldPrayerTimesScreenState();
}

class _WorldPrayerTimesScreenState extends ConsumerState<WorldPrayerTimesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  // Gulf country codes
  static const Set<String> _gulfCodes = {'SA', 'AE', 'QA', 'KW', 'BH', 'OM'};
  // Arab countries
  static const Set<String> _levantArabCodes = {
    'EG', 'JO', 'PS', 'SY', 'LB', 'YE', 'SD', 'MA', 'DZ', 'TN', 'LY', 'MR', 'SO', 'DJ', 'KM'
  };
  // Europe
  static const Set<String> _europeCodes = {
    'DE', 'GB', 'SE', 'NO', 'DK', 'FI', 'NL', 'BE', 'FR', 'CH', 'AT', 'IT', 'ES', 'GR',
    'AL', 'AD', 'BY', 'BA', 'BG', 'HR', 'CY', 'CZ', 'EE', 'HU', 'IS', 'IE', 'XK', 'LV',
    'LI', 'LT', 'LU', 'MT', 'MD', 'MC', 'ME', 'MK', 'PL', 'PT', 'RO', 'RU', 'SM', 'RS',
    'SK', 'SI', 'UA', 'VA'
  };
  // Americas
  static const Set<String> _americasCodes = {
    'US', 'CA', 'MX', 'BR', 'AR', 'CL', 'CO', 'PE', 'VE', 'CU', 'DO', 'EC', 'GT',
    'PA', 'BO', 'CR', 'UY', 'PY', 'JM', 'TT', 'HN', 'SV', 'NI', 'HT', 'BS', 'BB',
    'GY', 'SR', 'BZ', 'LC', 'VC', 'GD', 'AG', 'DM', 'KN'
  };
  // Africa
  static const Set<String> _africaCodes = {
    'NG', 'ET', 'ZA', 'KE', 'TZ', 'UG', 'GH', 'SN', 'CI', 'ML', 'NE', 'BF', 'GN',
    'TD', 'ZW', 'RW', 'BI', 'CM', 'AO', 'MZ', 'ZM', 'MW', 'MG', 'BJ', 'TG', 'SL',
    'LR', 'CF', 'CG', 'CD', 'GA', 'GQ', 'GW', 'GM', 'ST', 'CV', 'SC', 'MU', 'BW',
    'NA', 'LS', 'SZ', 'ER', 'SS'
  };
  // Asia & Oceania
  static const Set<String> _asiaOceaniaCodes = {
    'PK', 'IN', 'BD', 'ID', 'MY', 'AF', 'AZ', 'UZ', 'KZ', 'TM', 'KG', 'TJ',
    'JP', 'KR', 'CN', 'TH', 'VN', 'PH', 'SG', 'LK', 'MM', 'NP', 'KH', 'MN', 'TW',
    'MV', 'BN', 'BT', 'LA', 'TL', 'AU', 'NZ', 'FJ', 'PG', 'WS', 'TO', 'VU', 'SB',
    'FM', 'KI', 'MH', 'NR', 'PW', 'TV'
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getCountryFlag(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code == 'IQ') return '☀️';
    if (code.length == 2) {
      final a = code.codeUnitAt(0);
      final b = code.codeUnitAt(1);
      if (a >= 65 && a <= 90 && b >= 65 && b <= 90) {
        return String.fromCharCodes([0x1F1E6 + (a - 65), 0x1F1E6 + (b - 65)]);
      }
    }
    return '🌍';
  }

  bool _matchesCategory(City city, String category) {
    if (category == 'all') return true;
    final code = city.country.toUpperCase();
    switch (category) {
      case 'kurdistan_iraq':
        return code == 'IQ';
      case 'gulf':
        return _gulfCodes.contains(code);
      case 'levant_arab':
        return _levantArabCodes.contains(code);
      case 'europe':
        return _europeCodes.contains(code);
      case 'turkey':
        return code == 'TR';
      case 'iran':
        return code == 'IR';
      case 'americas':
        return _americasCodes.contains(code);
      case 'africa':
        return _africaCodes.contains(code);
      case 'asia':
        return _asiaOceaniaCodes.contains(code);
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final citiesAsync = ref.watch(citiesFutureProvider);
    final lang = settings.language;
    final isRTL = lang == 'ku' || lang == 'ar';

    final categories = [
      {'id': 'all', 'label': lang == 'ku' ? '🌐 هەمووی' : (lang == 'ar' ? '🌐 الكل' : '🌐 All')},
      {'id': 'kurdistan_iraq', 'label': lang == 'ku' ? '☀️ کوردستان و عێراق' : (lang == 'ar' ? '☀️ كردستان والعراق' : '☀️ Kurdistan & Iraq')},
      {'id': 'gulf', 'label': lang == 'ku' ? '🇸🇦 کەنداو' : (lang == 'ar' ? '🇸🇦 الخليج' : '🇸🇦 Gulf')},
      {'id': 'levant_arab', 'label': lang == 'ku' ? '🌙 وڵاتانی عەرەبی' : (lang == 'ar' ? '🌙 الدول العربية' : '🌙 Arab World')},
      {'id': 'europe', 'label': lang == 'ku' ? '🇪🇺 ئەوروپا' : (lang == 'ar' ? '🇪🇺 أوروبا' : '🇪🇺 Europe')},
      {'id': 'turkey', 'label': lang == 'ku' ? '🇹🇷 تورکیا' : (lang == 'ar' ? '🇹🇷 تركيا' : '🇹🇷 Turkey')},
      {'id': 'iran', 'label': lang == 'ku' ? '🇮🇷 ئێران' : (lang == 'ar' ? '🇮🇷 إيران' : '🇮🇷 Iran')},
      {'id': 'americas', 'label': lang == 'ku' ? '🌎 ئەمریکا' : (lang == 'ar' ? '🌎 الأمريكتين' : '🌎 Americas')},
      {'id': 'africa', 'label': lang == 'ku' ? '🌍 ئەفریقا' : (lang == 'ar' ? '🌍 أفريقيا' : '🌍 Africa')},
      {'id': 'asia', 'label': lang == 'ku' ? '🌏 ئاسیا' : (lang == 'ar' ? '🌏 آسيا' : '🌏 Asia')},
    ];

    final prayerNames = {
      'Fajr': {'ku': 'بەیانی', 'ar': 'الفجر', 'en': 'Fajr', 'icon': '🌅'},
      'Sunrise': {'ku': 'ڕۆژهەڵات', 'ar': 'الشروق', 'en': 'Sunrise', 'icon': '☀️'},
      'Dhuhr': {'ku': 'نیوەڕۆ', 'ar': 'الظهر', 'en': 'Dhuhr', 'icon': '🌤️'},
      'Asr': {'ku': 'عەسڕ', 'ar': 'العصر', 'en': 'Asr', 'icon': '🌥️'},
      'Maghrib': {'ku': 'مەغریب', 'ar': 'المغرب', 'en': 'Maghrib', 'icon': '🌆'},
      'Isha': {'ku': 'عیشا', 'ar': 'العشاء', 'en': 'Isha', 'icon': '🌙'},
    };

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
          elevation: 0,
          title: Text(
            lang == 'ku'
                ? 'کاتەکانی بانگی هەموو وڵاتان'
                : (lang == 'ar' ? 'مواقيت الصلاة لجميع الدول' : 'World Prayer Times'),
            style: const TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'Rabar',
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: citiesAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: primaryColor)),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
          data: (allCities) {
            final filteredCities = allCities.where((c) {
              if (_searchQuery.isNotEmpty) {
                final ku = c.ku.toLowerCase();
                final ar = c.ar.toLowerCase();
                final en = c.en.toLowerCase();
                final countryKu = c.countryKu.toLowerCase();
                final country = c.country.toLowerCase();
                final countryAr = (c.countryAr ?? '').toLowerCase();
                final countryEn = (c.countryEn ?? '').toLowerCase();

                return ku.contains(_searchQuery) ||
                    ar.contains(_searchQuery) ||
                    en.contains(_searchQuery) ||
                    countryKu.contains(_searchQuery) ||
                    country.contains(_searchQuery) ||
                    countryAr.contains(_searchQuery) ||
                    countryEn.contains(_searchQuery);
              }
              return _matchesCategory(c, _selectedCategory);
            }).toList();

            return Column(
              children: [
                // Top Search Bar
                Container(
                  color: theme.cardColor,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      hintText: lang == 'ku'
                          ? 'گەڕان بۆ هەر شار یان دەوڵەتێکی جیهان...'
                          : (lang == 'ar'
                              ? 'ابحث عن أي مدينة أو دولة في العالم...'
                              : 'Search any city or country in the world...'),
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 13.5,
                        fontFamily: 'Rabar',
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 21),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: primaryColor, width: 1.3),
                      ),
                    ),
                  ),
                ),

                // Category Chips Carousel
                Container(
                  color: theme.cardColor,
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    itemCount: categories.length,
                    itemBuilder: (context, idx) {
                      final cat = categories[idx];
                      final isCatSelected = _selectedCategory == cat['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            cat['label']!,
                            style: TextStyle(
                              fontFamily: 'Rabar',
                              fontSize: 12.5,
                              fontWeight: isCatSelected ? FontWeight.bold : FontWeight.w500,
                              color: isCatSelected ? Colors.black : Colors.white,
                            ),
                          ),
                          selected: isCatSelected,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedCategory = cat['id']!;
                            });
                          },
                          backgroundColor: Colors.white.withOpacity(0.05),
                          selectedColor: primaryColor,
                          checkmarkColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isCatSelected ? primaryColor : Colors.white.withOpacity(0.08),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1, color: Colors.white10),

                // Cities & Prayer Times List
                Expanded(
                  child: filteredCities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 52, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              Text(
                                lang == 'ku'
                                    ? 'هیچ شار یان وڵاتێک نەدۆزرایەوە'
                                    : (lang == 'ar' ? 'لم يتم العثور على أي مدينة أو دولة' : 'No cities or countries found'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontFamily: 'Rabar',
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredCities.length,
                          itemBuilder: (context, idx) {
                            final city = filteredCities[idx];
                            final isActive = city.id == settings.userCityId;
                            final flag = _getCountryFlag(city.country);
                            final cityName = lang == 'ar'
                                ? city.ar
                                : (lang == 'en' ? city.en : city.ku);
                            final countryName = lang == 'ar'
                                ? (city.countryAr ?? city.countryKu)
                                : (lang == 'en' ? (city.countryEn ?? city.country) : city.countryKu);

                            // Calculate today's exact prayer times for this city
                            final times = PrayerService.calculateTimes(
                              latitude: city.lat,
                              longitude: city.lng,
                              method: city.country == 'IQ' ? 'KRG' : settings.calculationMethod,
                              asrMadhab: settings.asrMadhab,
                              offsets: const {},
                              cityId: city.id,
                              countryCode: city.country,
                            );

                            final nextPrayer = PrayerService.getNextPrayer(times);
                            final nextPrayerLocalized = prayerNames[nextPrayer['name']]?[lang] ?? nextPrayer['name'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive
                                      ? primaryColor
                                      : Colors.white.withOpacity(0.07),
                                  width: isActive ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Header: Flag + Name + Set Active Button
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.06),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(flag, style: const TextStyle(fontSize: 22)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      cityName,
                                                      style: TextStyle(
                                                        fontFamily: 'Rabar',
                                                        fontSize: 16.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: isActive ? primaryColor : Colors.white,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isActive) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: primaryColor.withOpacity(0.18),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: primaryColor.withOpacity(0.4), width: 0.8),
                                                      ),
                                                      child: Text(
                                                        lang == 'ku' ? 'شاری ئێستا' : (lang == 'ar' ? 'الحالية' : 'Current'),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: primaryColor,
                                                          fontFamily: 'Rabar',
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                countryName,
                                                style: TextStyle(
                                                  fontFamily: 'Rabar',
                                                  fontSize: 12.5,
                                                  color: Colors.white.withOpacity(0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Set as active button
                                        InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () {
                                            HapticFeedback.mediumImpact();
                                            ref.read(settingsProvider.notifier).setUserCityId(city.id);
                                            ref.read(settingsProvider.notifier).setUseGPS(false);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  lang == 'ku'
                                                      ? 'شاری سەرەکی گۆڕدرا بۆ: $cityName'
                                                      : (lang == 'ar'
                                                          ? 'تم تغيير المدينة إلى: $cityName'
                                                          : 'Active city set to: $cityName'),
                                                  style: const TextStyle(fontFamily: 'Rabar'),
                                                ),
                                                backgroundColor: primaryColor,
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? primaryColor.withOpacity(0.15)
                                                  : Colors.white.withOpacity(0.06),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isActive
                                                    ? primaryColor
                                                    : Colors.white.withOpacity(0.1),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isActive
                                                      ? Icons.check_circle_rounded
                                                      : Icons.radio_button_unchecked_rounded,
                                                  color: isActive ? primaryColor : Colors.white70,
                                                  size: 15,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  isActive
                                                      ? (lang == 'ku' ? 'هەڵبژێردراو' : (lang == 'ar' ? 'محدد' : 'Selected'))
                                                      : (lang == 'ku' ? 'دانان' : (lang == 'ar' ? 'تعيين' : 'Set')),
                                                  style: TextStyle(
                                                    fontFamily: 'Rabar',
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isActive ? primaryColor : Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Next Prayer Bar
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                prayerNames[nextPrayer['name']]?['icon'] ?? '🕌',
                                                style: const TextStyle(fontSize: 15),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                lang == 'ku'
                                                    ? 'نوێژی داهاتوو: $nextPrayerLocalized'
                                                    : (lang == 'ar'
                                                        ? 'الصلاة القادمة: $nextPrayerLocalized'
                                                        : 'Next: $nextPrayerLocalized'),
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontFamily: 'Rabar',
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            nextPrayer['time'] ?? '--:--',
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // 6 Prayer Times Horizontal Grid
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildPrayerTimeChip(
                                          title: prayerNames['Fajr']?[lang] ?? 'Fajr',
                                          time: times['Fajr'] ?? '--:--',
                                          icon: '🌅',
                                          isNext: nextPrayer['name'] == 'Fajr',
                                          primaryColor: primaryColor,
                                        ),
                                        _buildPrayerTimeChip(
                                          title: prayerNames['Sunrise']?[lang] ?? 'Sunrise',
                                          time: times['Sunrise'] ?? '--:--',
                                          icon: '☀️',
                                          isNext: false,
                                          primaryColor: primaryColor,
                                        ),
                                        _buildPrayerTimeChip(
                                          title: prayerNames['Dhuhr']?[lang] ?? 'Dhuhr',
                                          time: times['Dhuhr'] ?? '--:--',
                                          icon: '🌤️',
                                          isNext: nextPrayer['name'] == 'Dhuhr',
                                          primaryColor: primaryColor,
                                        ),
                                        _buildPrayerTimeChip(
                                          title: prayerNames['Asr']?[lang] ?? 'Asr',
                                          time: times['Asr'] ?? '--:--',
                                          icon: '🌥️',
                                          isNext: nextPrayer['name'] == 'Asr',
                                          primaryColor: primaryColor,
                                        ),
                                        _buildPrayerTimeChip(
                                          title: prayerNames['Maghrib']?[lang] ?? 'Maghrib',
                                          time: times['Maghrib'] ?? '--:--',
                                          icon: '🌆',
                                          isNext: nextPrayer['name'] == 'Maghrib',
                                          primaryColor: primaryColor,
                                        ),
                                        _buildPrayerTimeChip(
                                          title: prayerNames['Isha']?[lang] ?? 'Isha',
                                          time: times['Isha'] ?? '--:--',
                                          icon: '🌙',
                                          isNext: nextPrayer['name'] == 'Isha',
                                          primaryColor: primaryColor,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPrayerTimeChip({
    required String title,
    required String time,
    required String icon,
    required bool isNext,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isNext ? primaryColor.withOpacity(0.18) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNext ? primaryColor : Colors.white.withOpacity(0.05),
          width: isNext ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'Rabar',
              color: isNext ? primaryColor : Colors.white70,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isNext ? primaryColor : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
