import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemePalette {
  final String id;
  final String nameKu;
  final String nameAr;
  final String nameEn;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color cardColor;

  const AppThemePalette({
    required this.id,
    required this.nameKu,
    required this.nameAr,
    required this.nameEn,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.cardColor,
  });

  static const List<AppThemePalette> themes = [
    AppThemePalette(
      id: 'gold',
      nameKu: '🌙 زێڕینی درەوشاوە (Midnight Gold)',
      nameAr: '🌙 الذهبي الملكي',
      nameEn: 'Midnight Gold',
      primaryColor: Color(0xFFD4AF37),
      secondaryColor: Color(0xFFF59E0B),
      backgroundColor: Color(0xFF0B0E14),
      cardColor: Color(0xFF131822),
    ),
    AppThemePalette(
      id: 'emerald',
      nameKu: '🌿 سەوزی زومڕەتی (Emerald Green)',
      nameAr: '🌿 الأخضر الزمردي',
      nameEn: 'Emerald Green',
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF059669),
      backgroundColor: Color(0xFF061814),
      cardColor: Color(0xFF0C2721),
    ),
    AppThemePalette(
      id: 'sapphire',
      nameKu: '🔷 شینی یاقووتی (Royal Sapphire)',
      nameAr: '🔷 الأزرق الملكي',
      nameEn: 'Royal Sapphire',
      primaryColor: Color(0xFF3B82F6),
      secondaryColor: Color(0xFF2563EB),
      backgroundColor: Color(0xFF071120),
      cardColor: Color(0xFF0E1E36),
    ),
    AppThemePalette(
      id: 'obsidian',
      nameKu: '🌌 مۆری شەوانە (Obsidian Purple)',
      nameAr: '🌌 البنفسجي الملكي',
      nameEn: 'Obsidian Purple',
      primaryColor: Color(0xFFA855F7),
      secondaryColor: Color(0xFF9333EA),
      backgroundColor: Color(0xFF0F0A1C),
      cardColor: Color(0xFF19122C),
    ),
    AppThemePalette(
      id: 'crimson',
      nameKu: '🔴 سووری گەش (Deep Crimson)',
      nameAr: '🔴 القرمزي الدافئ',
      nameEn: 'Deep Crimson',
      primaryColor: Color(0xFFEF4444),
      secondaryColor: Color(0xFFDC2626),
      backgroundColor: Color(0xFF180808),
      cardColor: Color(0xFF261010),
    ),
    AppThemePalette(
      id: 'teal',
      nameKu: '🌊 شینی دەریا (Ocean Teal)',
      nameAr: '🌊 الفيروزي البحري',
      nameEn: 'Ocean Teal',
      primaryColor: Color(0xFF14B8A6),
      secondaryColor: Color(0xFF0D9488),
      backgroundColor: Color(0xFF061617),
      cardColor: Color(0xFF0D2527),
    ),
  ];

  static AppThemePalette getTheme(String id) {
    return themes.firstWhere((t) => t.id == id, orElse: () => themes.first);
  }
}

class SettingsState {
  final String? _language;
  final String? _themeName;
  final String? _notificationSound;
  final String? _selectedAdhanVoice;
  final String? _selectedFajrAdhanVoice;
  final bool? _useGPS;
  final String? _userCityId;
  final String? _calculationMethod;
  final String? _asrMadhab;
  final Map<String, int>? _prayerOffsets;
  final Map<String, bool>? _prayerNotifications;
  final int? _hijriAdjustment;
  final double? _quranArabicFontSize;
  final double? _quranTranslationFontSize;
  final String? _quranFontFamily;

  SettingsState({
    String? language,
    String? themeName,
    String? notificationSound,
    String? selectedAdhanVoice,
    String? selectedFajrAdhanVoice,
    bool? useGPS,
    String? userCityId,
    String? calculationMethod,
    String? asrMadhab,
    Map<String, int>? prayerOffsets,
    Map<String, bool>? prayerNotifications,
    int? hijriAdjustment,
    double? quranArabicFontSize,
    double? quranTranslationFontSize,
    String? quranFontFamily,
  })  : _language = language ?? 'ku',
        _themeName = themeName ?? 'gold',
        _notificationSound = notificationSound ?? 'adhan',
        _selectedAdhanVoice = (selectedAdhanVoice == null || selectedAdhanVoice == 'mishary') ? 'nasser' : selectedAdhanVoice,
        _selectedFajrAdhanVoice = selectedFajrAdhanVoice ?? 'mishary_fajr',
        _useGPS = useGPS ?? true,
        _userCityId = userCityId ?? 'erbil',
        _calculationMethod = calculationMethod ?? 'KRG',
        _asrMadhab = asrMadhab ?? 'Shafi',
        _prayerOffsets = prayerOffsets ?? const {'Fajr': 0, 'Sunrise': 0, 'Dhuhr': 0, 'Asr': 0, 'Maghrib': 0, 'Isha': 0},
        _prayerNotifications = prayerNotifications ?? const {'Fajr': true, 'Dhuhr': true, 'Asr': true, 'Maghrib': true, 'Isha': true},
        _hijriAdjustment = hijriAdjustment ?? 0,
        _quranArabicFontSize = quranArabicFontSize ?? 24.0,
        _quranTranslationFontSize = quranTranslationFontSize ?? 15.0,
        _quranFontFamily = quranFontFamily ?? 'Traditional Arabic';

  String get language => _language ?? 'ku';
  String get themeName => _themeName ?? 'gold';
  String get notificationSound => _notificationSound ?? 'adhan';
  String get selectedAdhanVoice => _selectedAdhanVoice ?? 'nasser';
  String get selectedFajrAdhanVoice => _selectedFajrAdhanVoice ?? 'mishary_fajr';
  bool get useGPS => _useGPS ?? true;
  String get userCityId => _userCityId ?? 'erbil';
  String get calculationMethod => _calculationMethod ?? 'KRG';
  String get asrMadhab => _asrMadhab ?? 'Shafi';
  Map<String, int> get prayerOffsets => _prayerOffsets ?? const {'Fajr': 0, 'Sunrise': 0, 'Dhuhr': 0, 'Asr': 0, 'Maghrib': 0, 'Isha': 0};
  Map<String, bool> get prayerNotifications => _prayerNotifications ?? const {'Fajr': true, 'Dhuhr': true, 'Asr': true, 'Maghrib': true, 'Isha': true};
  int get hijriAdjustment => _hijriAdjustment ?? 0;
  double get quranArabicFontSize => _quranArabicFontSize ?? 24.0;
  double get quranTranslationFontSize => _quranTranslationFontSize ?? 15.0;
  String get quranFontFamily => _quranFontFamily ?? 'Traditional Arabic';

  AppThemePalette get palette => AppThemePalette.getTheme(themeName);

  SettingsState copyWith({
    String? language,
    String? themeName,
    String? notificationSound,
    String? selectedAdhanVoice,
    String? selectedFajrAdhanVoice,
    bool? useGPS,
    String? userCityId,
    String? calculationMethod,
    String? asrMadhab,
    Map<String, int>? prayerOffsets,
    Map<String, bool>? prayerNotifications,
    int? hijriAdjustment,
    double? quranArabicFontSize,
    double? quranTranslationFontSize,
    String? quranFontFamily,
  }) {
    return SettingsState(
      language: language ?? this.language,
      themeName: themeName ?? this.themeName,
      notificationSound: notificationSound ?? this.notificationSound,
      selectedAdhanVoice: selectedAdhanVoice ?? this.selectedAdhanVoice,
      selectedFajrAdhanVoice: selectedFajrAdhanVoice ?? this.selectedFajrAdhanVoice,
      useGPS: useGPS ?? this.useGPS,
      userCityId: userCityId ?? this.userCityId,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrMadhab: asrMadhab ?? this.asrMadhab,
      prayerOffsets: prayerOffsets ?? this.prayerOffsets,
      prayerNotifications: prayerNotifications ?? this.prayerNotifications,
      hijriAdjustment: hijriAdjustment ?? this.hijriAdjustment,
      quranArabicFontSize: quranArabicFontSize ?? this.quranArabicFontSize,
      quranTranslationFontSize: quranTranslationFontSize ?? this.quranTranslationFontSize,
      quranFontFamily: quranFontFamily ?? this.quranFontFamily,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          language: _prefs.getString('language') ?? 'ku',
          themeName: _prefs.getString('themeName') ?? 'gold',
          notificationSound: _prefs.getString('notificationSound') ?? 'adhan',
          selectedAdhanVoice: (_prefs.getString('selectedAdhanVoice') == null || _prefs.getString('selectedAdhanVoice') == 'mishary') ? 'nasser' : _prefs.getString('selectedAdhanVoice')!,
          selectedFajrAdhanVoice: _prefs.getString('selectedFajrAdhanVoice') ?? 'mishary_fajr',
          useGPS: _prefs.getBool('useGPS') ?? true,
          userCityId: _prefs.getString('userCityId') ?? 'erbil',
          calculationMethod: _prefs.getString('calculationMethod') ?? 'KRG',
          asrMadhab: _prefs.getString('asrMadhab') ?? 'Shafi',
          prayerOffsets: _loadOffsets(_prefs),
          prayerNotifications: _loadNotifications(_prefs),
          hijriAdjustment: _prefs.getInt('hijriAdjustment') ?? 0,
          quranArabicFontSize: _prefs.getDouble('quranArabicFontSize') ?? 24.0,
          quranTranslationFontSize: _prefs.getDouble('quranTranslationFontSize') ?? 15.0,
          quranFontFamily: _prefs.getString('quranFontFamily') ?? 'Traditional Arabic',
        ));

  static Map<String, int> _loadOffsets(SharedPreferences prefs) {
    const defaults = {'Fajr': 0, 'Sunrise': 0, 'Dhuhr': 0, 'Asr': 0, 'Maghrib': 0, 'Isha': 0};
    final raw = prefs.getString('prayerOffsets');
    if (raw == null) {
      return Map.from(defaults);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = Map<String, int>.from(defaults);
      map.forEach((key, value) {
        if (value is num) {
          result[key] = value.toInt();
        }
      });
      return result;
    } catch (e) {
      debugPrint('[SettingsProvider] Error loading data: $e');
      return Map.from(defaults);
    }
  }

  static Map<String, bool> _loadNotifications(SharedPreferences prefs) {
    const defaults = {'Fajr': true, 'Dhuhr': true, 'Asr': true, 'Maghrib': true, 'Isha': true};
    final raw = prefs.getString('prayerNotifications');
    if (raw == null) {
      return Map.from(defaults);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = Map<String, bool>.from(defaults);
      map.forEach((key, value) {
        if (value is bool) {
          result[key] = value;
        }
      });
      return result;
    } catch (e) {
      debugPrint('[SettingsProvider] Error loading data: $e');
      return Map.from(defaults);
    }
  }

  Future<void> setLanguage(String lang) async {
    await _prefs.setString('language', lang);
    state = state.copyWith(language: lang);
  }

  Future<void> setThemeName(String theme) async {
    await _prefs.setString('themeName', theme);
    state = state.copyWith(themeName: theme);
  }

  Future<void> setNotificationSound(String sound) async {
    await _prefs.setString('notificationSound', sound);
    state = state.copyWith(notificationSound: sound);
  }

  Future<void> setSelectedAdhanVoice(String voice) async {
    await _prefs.setString('selectedAdhanVoice', voice);
    state = state.copyWith(selectedAdhanVoice: voice);
  }

  Future<void> setSelectedFajrAdhanVoice(String voice) async {
    await _prefs.setString('selectedFajrAdhanVoice', voice);
    state = state.copyWith(selectedFajrAdhanVoice: voice);
  }

  Future<void> setUseGPS(bool val) async {
    await _prefs.setBool('useGPS', val);
    state = state.copyWith(useGPS: val);
  }

  Future<void> setUserCityId(String cityId) async {
    await _prefs.setString('userCityId', cityId);
    state = state.copyWith(userCityId: cityId);
  }

  Future<void> setCalculationMethod(String method) async {
    await _prefs.setString('calculationMethod', method);
    state = state.copyWith(calculationMethod: method);
  }

  Future<void> setAsrMadhab(String madhab) async {
    await _prefs.setString('asrMadhab', madhab);
    state = state.copyWith(asrMadhab: madhab);
  }

  Future<void> setPrayerOffsets(Map<String, int> offsets) async {
    await _prefs.setString('prayerOffsets', jsonEncode(offsets));
    state = state.copyWith(prayerOffsets: offsets);
  }

  Future<void> setPrayerNotification(String prayer, bool val) async {
    final copy = Map<String, bool>.from(state.prayerNotifications);
    copy[prayer] = val;
    await _prefs.setString('prayerNotifications', jsonEncode(copy));
    state = state.copyWith(prayerNotifications: copy);
  }

  Future<void> setHijriAdjustment(int days) async {
    await _prefs.setInt('hijriAdjustment', days);
    state = state.copyWith(hijriAdjustment: days);
  }

  Future<void> setQuranArabicFontSize(double size) async {
    await _prefs.setDouble('quranArabicFontSize', size);
    state = state.copyWith(quranArabicFontSize: size);
  }

  Future<void> setQuranTranslationFontSize(double size) async {
    await _prefs.setDouble('quranTranslationFontSize', size);
    state = state.copyWith(quranTranslationFontSize: size);
  }

  Future<void> setQuranFontFamily(String font) async {
    await _prefs.setString('quranFontFamily', font);
    state = state.copyWith(quranFontFamily: font);
  }
}

// Global provider declarations
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize this provider in main() before app starts!');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
