import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/city.dart';
import '../providers/settings_provider.dart';
import '../services/location_service.dart';
import '../services/prayer_service.dart';

class CitySelectorSheet extends StatefulWidget {
  final List<City> cities;
  final String currentCityId;
  final String language;

  const CitySelectorSheet({
    super.key,
    required this.cities,
    required this.currentCityId,
    required this.language,
  });

  static Future<void> show(
    BuildContext context, {
    required List<City> cities,
    required String currentCityId,
    required String language,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CitySelectorSheet(
        cities: cities,
        currentCityId: currentCityId,
        language: language,
      ),
    );
  }

  @override
  State<CitySelectorSheet> createState() => _CitySelectorSheetState();
}

class _CitySelectorSheetState extends State<CitySelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _searchQuery = '';

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
    if (code == 'IQ') {
      return '☀️';
    }
    if (code.length == 2) {
      final a = code.codeUnitAt(0);
      final b = code.codeUnitAt(1);
      if (a >= 65 && a <= 90 && b >= 65 && b <= 90) {
        return String.fromCharCodes([0x1F1E6 + (a - 65), 0x1F1E6 + (b - 65)]);
      }
    }
    return '🌍';
  }

  static const Set<String> _gulfCodes = {'SA', 'AE', 'QA', 'KW', 'BH', 'OM'};
  static const Set<String> _levantArabCodes = {
    'EG', 'JO', 'PS', 'SY', 'LB', 'YE', 'SD', 'MA', 'DZ', 'TN', 'LY', 'MR', 'SO', 'DJ', 'KM'
  };
  static const Set<String> _europeCodes = {
    'DE', 'GB', 'SE', 'NO', 'DK', 'FI', 'NL', 'BE', 'FR', 'CH', 'AT', 'IT', 'ES', 'GR',
    'AL', 'AD', 'BY', 'BA', 'BG', 'HR', 'CY', 'CZ', 'EE', 'HU', 'IS', 'IE', 'XK', 'LV',
    'LI', 'LT', 'LU', 'MT', 'MD', 'MC', 'ME', 'MK', 'PL', 'PT', 'RO', 'RU', 'SM', 'RS',
    'SK', 'SI', 'UA', 'VA'
  };
  static const Set<String> _americasCodes = {
    'US', 'CA', 'MX', 'BR', 'AR', 'CL', 'CO', 'PE', 'VE', 'CU', 'DO', 'EC', 'GT',
    'PA', 'BO', 'CR', 'UY', 'PY', 'JM', 'TT', 'HN', 'SV', 'NI', 'HT', 'BS', 'BB',
    'GY', 'SR', 'BZ', 'LC', 'VC', 'GD', 'AG', 'DM', 'KN'
  };
  static const Set<String> _africaCodes = {
    'NG', 'ET', 'ZA', 'KE', 'TZ', 'UG', 'GH', 'SN', 'CI', 'ML', 'NE', 'BF', 'GN',
    'TD', 'ZW', 'RW', 'BI', 'CM', 'AO', 'MZ', 'ZM', 'MW', 'MG', 'BJ', 'TG', 'SL',
    'LR', 'CF', 'CG', 'CD', 'GA', 'GQ', 'GW', 'GM', 'ST', 'CV', 'SC', 'MU', 'BW',
    'NA', 'LS', 'SZ', 'ER', 'SS'
  };
  static const Set<String> _asiaOceaniaCodes = {
    'PK', 'IN', 'BD', 'ID', 'MY', 'AF', 'AZ', 'UZ', 'KZ', 'TM', 'KG', 'TJ',
    'JP', 'KR', 'CN', 'TH', 'VN', 'PH', 'SG', 'LK', 'MM', 'NP', 'KH', 'MN', 'TW',
    'MV', 'BN', 'BT', 'LA', 'TL', 'AU', 'NZ', 'FJ', 'PG', 'WS', 'TO', 'VU', 'SB',
    'FM', 'KI', 'MH', 'NR', 'PW', 'TV'
  };

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

  void _onCitySelected(WidgetRef ref, City city) {
    HapticFeedback.selectionClick();
    ref.read(settingsProvider.notifier).setUserCityId(city.id);
    ref.read(settingsProvider.notifier).setUseGPS(false);

    // Automatically adapt calculation method according to country standards
    final code = city.country.toUpperCase();
    if (code == 'IQ') {
      ref.read(settingsProvider.notifier).setCalculationMethod('KRG');
    } else if (_gulfCodes.contains(code)) {
      ref.read(settingsProvider.notifier).setCalculationMethod('UmmAlQura');
    } else if (['US', 'CA'].contains(code)) {
      ref.read(settingsProvider.notifier).setCalculationMethod('ISNA');
    } else if (code == 'TR') {
      ref.read(settingsProvider.notifier).setCalculationMethod('Diyanet');
    } else if (['PK', 'IN', 'BD', 'AF'].contains(code)) {
      ref.read(settingsProvider.notifier).setCalculationMethod('Karachi');
    } else if (_levantArabCodes.contains(code)) {
      ref.read(settingsProvider.notifier).setCalculationMethod('Egyptian');
    } else {
      ref.read(settingsProvider.notifier).setCalculationMethod('MuslimWorldLeague');
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;
    final isRTL = lang == 'ku' || lang == 'ar';

    final categories = [
      {'id': 'all', 'label': lang == 'ku' ? '🌐 هەمووی (${widget.cities.length})' : (lang == 'ar' ? '🌐 الكل (${widget.cities.length})' : '🌐 All (${widget.cities.length})')},
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

    final filteredCities = widget.cities.where((c) {
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

    return Consumer(
      builder: (context, ref, _) {
        final theme = Theme.of(context);
        final primaryColor = theme.colorScheme.primary;

        return Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Pull notch
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.public_rounded, color: primaryColor, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lang == 'ku'
                                  ? 'هەڵبژاردنی شار و وڵات'
                                  : (lang == 'ar' ? 'اختيار المدينة والدولة' : 'Select City & Country'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Rabar',
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.cities.length} ${lang == 'ku' ? 'شار' : (lang == 'ar' ? 'مدينة' : 'Cities')}',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Rabar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.09)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Rabar'),
                          decoration: InputDecoration(
                            hintText: lang == 'ku'
                                ? 'گەڕان بۆ شار یان وڵات (وەک: لەندەن، مەککە، ستۆکهۆڵم، بەرلین)...'
                                : (lang == 'ar'
                                    ? 'ابحث عن مدينة أو دولة (مثل: مكة، لندن، برلين، ستوكهولم)...'
                                    : 'Search city or country (e.g. London, Makkah, Berlin)...'),
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, fontFamily: 'Rabar'),
                            prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // GPS Quick Action Banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final nearest = await LocationService.detectNearestCity(widget.cities);
                          if (nearest != null) {
                            ref.read(settingsProvider.notifier).setUserCityId(nearest.id);
                            ref.read(settingsProvider.notifier).setUseGPS(true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    lang == 'ku'
                                        ? 'نزیکترین شار دیاریکرا: ${nearest.ku}'
                                        : (lang == 'ar' ? 'تم تحديد المدينة: ${nearest.ar}' : 'Detected: ${nearest.en}'),
                                    style: const TextStyle(fontFamily: 'Rabar'),
                                  ),
                                  backgroundColor: primaryColor,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor.withOpacity(0.18), primaryColor.withOpacity(0.06)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: primaryColor.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.my_location_rounded, color: primaryColor, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lang == 'ku'
                                      ? 'دیاریکردنی ئۆتۆماتیکی شوێنەکەم (GPS)'
                                      : (lang == 'ar'
                                          ? 'تحديد موقعي التلقائي عبر الـ GPS'
                                          : 'Auto-detect nearest city (GPS)'),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Rabar',
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_left_rounded, color: primaryColor, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter Chips (Categories)
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final cat = categories[idx];
                          final isSelected = _selectedCategory == cat['id'];
                          return ChoiceChip(
                            label: Text(
                              cat['label']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.white70,
                                fontFamily: 'Rabar',
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            backgroundColor: Colors.white.withOpacity(0.04),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(
                              color: isSelected ? primaryColor : Colors.white.withOpacity(0.08),
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (_selectedCategory == cat['id']) {
                                  _selectedCategory = 'all';
                                } else {
                                  _selectedCategory = cat['id']!;
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    if (_selectedCategory != 'all') ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.filter_alt_rounded, size: 16, color: primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lang == 'ku'
                                      ? 'فلتەرکراوە: ${categories.firstWhere((e) => e['id'] == _selectedCategory, orElse: () => {'label': ''})['label']} (${filteredCities.length} شار)'
                                      : (lang == 'ar'
                                          ? 'مفلتر: ${categories.firstWhere((e) => e['id'] == _selectedCategory, orElse: () => {'label': ''})['label']} (${filteredCities.length} مدينة)'
                                          : 'Filtered: ${categories.firstWhere((e) => e['id'] == _selectedCategory, orElse: () => {'label': ''})['label']} (${filteredCities.length} cities)'),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 12,
                                    fontFamily: 'Rabar',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = 'all';
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        lang == 'ku' ? 'پیشاندانی هەمووی' : (lang == 'ar' ? 'عرض الكل' : 'Show All'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontFamily: 'Rabar',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white10, height: 1),

                    // Cities List
                    Expanded(
                      child: filteredCities.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: Colors.white.withOpacity(0.3)),
                                  const SizedBox(height: 10),
                                  Text(
                                    lang == 'ku'
                                        ? 'هیچ شارێک نەدۆزرایەوە'
                                        : (lang == 'ar' ? 'لم يتم العثور على أي مدينة' : 'No cities found'),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontFamily: 'Rabar',
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              itemCount: filteredCities.length,
                              itemBuilder: (context, idx) {
                                final city = filteredCities[idx];
                                final isSelected = city.id == widget.currentCityId;
                                final cityName = lang == 'ar'
                                    ? city.ar
                                    : lang == 'en'
                                        ? city.en
                                        : city.ku;
                                final countryName = lang == 'ar'
                                    ? (city.countryAr ?? city.countryKu)
                                    : lang == 'en'
                                        ? (city.countryEn ?? city.country)
                                        : city.countryKu;
                                final flag = _getCountryFlag(city.country);

                                final times = PrayerService.calculateTimes(
                                  latitude: city.lat,
                                  longitude: city.lng,
                                  method: city.country == 'IQ' ? 'KRG' : 'MuslimWorldLeague',
                                  asrMadhab: 'Shafi',
                                  offsets: const {},
                                  cityId: city.id,
                                  countryCode: city.country,
                                );
                                final next = PrayerService.getNextPrayer(times);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 7),
                                  child: Material(
                                    color: isSelected
                                        ? primaryColor.withOpacity(0.14)
                                        : Colors.white.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _onCitySelected(ref, city),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected ? primaryColor : Colors.white.withOpacity(0.05),
                                            width: isSelected ? 1.4 : 0.8,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                // Flag Avatar
                                                Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.05),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(flag, style: const TextStyle(fontSize: 18)),
                                                ),
                                                const SizedBox(width: 12),
                                                // City & Country
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        cityName,
                                                        style: TextStyle(
                                                          fontFamily: 'Rabar',
                                                          fontSize: 15,
                                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                          color: isSelected ? primaryColor : Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        countryName,
                                                        style: TextStyle(
                                                          fontFamily: 'Rabar',
                                                          fontSize: 12,
                                                          color: Colors.white.withOpacity(0.5),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Next prayer badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 0.8),
                                                  ),
                                                  child: Text(
                                                    '${next['time']}',
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Selection indicator
                                                if (isSelected)
                                                  Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            // Prayer times mini strip
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.03),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('🌅 ${times['Fajr']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                                  Text('☀️ ${times['Sunrise']}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                                  Text('🌤️ ${times['Dhuhr']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                                  Text('🌥️ ${times['Asr']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                                  Text('🌆 ${times['Maghrib']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                                  Text('🌙 ${times['Isha']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
