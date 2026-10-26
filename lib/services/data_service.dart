import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/city.dart';
import '../models/hadith.dart';
import '../models/adhkar.dart';

class DataService {
  static Map<String, dynamic>? _arabicData;
  static Map<String, dynamic>? _kuData;
  static Map<String, dynamic>? _enData;
  static Future<void>? _loadQuranFuture;

  static Map<String, Map<String, Map<String, String>>>? _awqafDatabase;
  static Future<void>? _loadAwqafFuture;

  static Map<String, Map<String, Map<String, String>>>? get awqafDatabase => _awqafDatabase;

  static void setAwqafDatabaseForTesting(Map<String, Map<String, Map<String, String>>> db) {
    _awqafDatabase = db;
  }

  static Future<Map<String, Map<String, Map<String, String>>>> loadAwqafPrayerDatabase() {
    if (_awqafDatabase != null) return Future.value(_awqafDatabase!);
    _loadAwqafFuture ??= () async {
      try {
        if (_awqafDatabase != null) return;
        String raw;
        try {
          raw = await rootBundle.loadString('assets/data/prayer_times.json');
        } catch (_) {
          if (!kIsWeb) {
            final file = File('assets/data/prayer_times.json');
            if (await file.exists()) {
              raw = await file.readAsString();
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        }

        final Map<String, dynamic> decoded = jsonDecode(raw);
        final Map<String, Map<String, Map<String, String>>> result = {};

        decoded.forEach((cityKey, records) {
          if (records is List) {
            final Map<String, Map<String, String>> dateMap = {};
            for (final item in records) {
              if (item is Map) {
                final dateKey = item['date']?.toString();
                if (dateKey != null) {
                  dateMap[dateKey] = {
                    'Fajr': item['fajr']?.toString() ?? '',
                    'Sunrise': item['sunrise']?.toString() ?? '',
                    'Dhuhr': item['dhuhr']?.toString() ?? '',
                    'Asr': item['asr']?.toString() ?? '',
                    'Maghrib': item['maghrib']?.toString() ?? '',
                    'Isha': item['isha']?.toString() ?? '',
                  };
                }
              }
            }
            result[cityKey.toString().toLowerCase()] = dateMap;
          }
        });
        _awqafDatabase = result;
      } catch (e) {
        debugPrint('[DataService] Error loading Awqaf prayer database: $e');
        _loadAwqafFuture = null;
      }
    }();
    return _loadAwqafFuture!.then((_) => _awqafDatabase ?? {});
  }

  static Future<void> _ensureQuranLoaded() {
    _loadQuranFuture ??= () async {
      try {
        if (_arabicData == null) {
          final rawAr = await rootBundle.loadString('assets/data/quran-offline/quran-arabic.json');
          _arabicData = jsonDecode(rawAr) as Map<String, dynamic>;
        }
        if (_kuData == null) {
          final rawKu = await rootBundle.loadString('assets/data/quran-offline/quran-ku-asan.json');
          _kuData = jsonDecode(rawKu) as Map<String, dynamic>;
        }
        if (_enData == null) {
          final rawEn = await rootBundle.loadString('assets/data/quran-offline/quran-en-asad.json');
          _enData = jsonDecode(rawEn) as Map<String, dynamic>;
        }
      } catch (e) {
        _loadQuranFuture = null; // allow retry if failed
        rethrow;
      }
    }();
    return _loadQuranFuture!;
  }

  static Future<List<City>> loadCities() async {
    try {
      final raw = await rootBundle.loadString('assets/data/cities.json');
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => City.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error loading cities: $e');
      return [];
    }
  }

  static Future<List<HadithCollection>> loadHadithCollections() async {
    try {
      final raw = await rootBundle.loadString('assets/data/hadith_collections.json');
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => HadithCollection.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error loading hadith collections: $e');
      return [];
    }
  }

  static Future<List<Hadith>> loadHadiths() async {
    try {
      final raw = await rootBundle.loadString('assets/data/hadith.json');
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => Hadith.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error loading hadiths: $e');
      return [];
    }
  }

  static Future<List<AdhkarCategory>> loadAdhkarCategories() async {
    try {
      final raw = await rootBundle.loadString('assets/data/adhkar_categories.json');
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => AdhkarCategory.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error loading adhkar categories: $e');
      return [];
    }
  }

  static Future<Map<String, List<AdhkarItem>>> loadAdhkarData() async {
    try {
      final raw = await rootBundle.loadString('assets/data/adhkar.json');
      final Map<String, dynamic> map = jsonDecode(raw);
      return map.map((key, value) {
        final List<dynamic> itemList = value;
        return MapEntry(
          key,
          itemList.map((item) => AdhkarItem.fromJson(item)).toList(),
        );
      });
    } catch (e) {
      debugPrint('Error loading adhkar data: $e');
      return {};
    }
  }

  static const Map<int, int> surahStartPages = {
    1: 1, 2: 2, 3: 50, 4: 77, 5: 106, 6: 128, 7: 151, 8: 177, 9: 187, 10: 208,
    11: 221, 12: 235, 13: 249, 14: 255, 15: 262, 16: 267, 17: 282, 18: 293, 19: 305, 20: 312,
    21: 322, 22: 332, 23: 342, 24: 350, 25: 359, 26: 367, 27: 377, 28: 385, 29: 396, 30: 404,
    31: 411, 32: 415, 33: 418, 34: 428, 35: 434, 36: 440, 37: 446, 38: 453, 39: 458, 40: 467,
    41: 477, 42: 483, 43: 489, 44: 496, 45: 499, 46: 502, 47: 507, 48: 511, 49: 515, 50: 518,
    51: 520, 52: 523, 53: 526, 54: 528, 55: 531, 56: 534, 57: 537, 58: 542, 59: 545, 60: 549,
    61: 551, 62: 553, 63: 554, 64: 556, 65: 558, 66: 560, 67: 562, 68: 564, 69: 566, 70: 568,
    71: 570, 72: 572, 73: 574, 74: 575, 75: 577, 76: 578, 77: 580, 78: 582, 79: 583, 80: 585,
    81: 586, 82: 587, 83: 587, 84: 589, 85: 590, 86: 591, 87: 591, 88: 592, 89: 593, 90: 594,
    91: 595, 92: 595, 93: 596, 94: 596, 95: 597, 96: 597, 97: 598, 98: 598, 99: 599, 100: 599,
    101: 600, 102: 600, 103: 601, 104: 601, 105: 601, 106: 602, 107: 602, 108: 602, 109: 603, 110: 603,
    111: 603, 112: 604, 113: 604, 114: 604,
  };

  static const Map<int, List<int>> juzPageRanges = {
    1: [1, 21], 2: [22, 41], 3: [42, 62], 4: [62, 81], 5: [82, 101],
    6: [102, 121], 7: [121, 141], 8: [142, 161], 9: [162, 181], 10: [182, 201],
    11: [201, 221], 12: [222, 241], 13: [242, 261], 14: [262, 281], 15: [282, 301],
    16: [302, 321], 17: [322, 341], 18: [342, 361], 19: [362, 381], 20: [382, 401],
    21: [402, 421], 22: [422, 441], 23: [442, 461], 24: [462, 481], 25: [482, 501],
    26: [502, 521], 27: [522, 541], 28: [542, 561], 29: [562, 581], 30: [582, 604],
  };

  static int getPageJuz(int page) {
    for (final entry in juzPageRanges.entries) {
      if (page >= entry.value[0] && page <= entry.value[1]) {
        return entry.key;
      }
    }
    return 1;
  }

  static Future<List<dynamic>> loadSurahInfo() async {
    try {
      final raw = await rootBundle.loadString('assets/data/surahs.json');
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) {
        final id = item['number'] as int;
        return {
          'id': id,
          'name_ar': item['name_ar'],
          'name_ku': item['name_ku'],
          'name_en': item['name_en'],
          'type': item['type'],
          'verses_count': item['verses'],
          'page': surahStartPages[id] ?? 1,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading surah info: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> loadSurahVerses(int surahNumber) async {
    try {
      final key = surahNumber.toString();
      
      await _ensureQuranLoaded();

      final List<dynamic> arVerses = _arabicData![key] ?? [];
      final List<dynamic> kuVerses = _kuData![key] ?? [];
      final List<dynamic> enVerses = _enData![key] ?? [];

      final List<Map<String, dynamic>> verses = [];
      for (int i = 0; i < arVerses.length; i++) {
        final int id = (arVerses[i]['numberInSurah'] as num?)?.toInt() ?? 0;
        final String text = (arVerses[i]['text'] ?? '').toString();
        final int page = (arVerses[i]['page'] as num?)?.toInt() ?? (surahStartPages[surahNumber] ?? 1);
        final int juz = (arVerses[i]['juz'] as num?)?.toInt() ?? 1;
        final bool sajda = arVerses[i]['sajda'] == true;
        
        String kuText = '';
        if (i < kuVerses.length) {
          kuText = (kuVerses[i]['text'] ?? '').toString();
        }
        
        String enText = '';
        if (i < enVerses.length) {
          enText = (enVerses[i]['text'] ?? '').toString();
        }

        verses.add({
          'id': id,
          'text': text,
          'page': page,
          'juz': juz,
          'sajda': sajda,
          'translations': {
            'kurdish': kuText,
            'english': enText,
          }
        });
      }

      return {
        'verses': verses,
      };
    } catch (e) {
      debugPrint('Error loading surah verses: $e');
      return {'verses': []};
    }
  }

  static Future<List<dynamic>> loadNames() async {
    try {
      final raw = await rootBundle.loadString('assets/data/names.json');
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading names: $e');
      return [];
    }
  }

  static Future<List<dynamic>> loadSunnahs() async {
    try {
      final raw = await rootBundle.loadString('assets/data/sunnah.json');
      final List<dynamic> list = jsonDecode(raw);
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return _fallbackSunnahs;
  }

  static Future<List<dynamic>> loadDailyVerses() async {
    try {
      final raw = await rootBundle.loadString('assets/data/daily_verses.json');
      final List<dynamic> list = jsonDecode(raw);
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('Error loading daily verses: $e');
    }
    return _fallbackDailyVerses;
  }

  static Future<List<dynamic>> loadRadio() async {
    try {
      final raw = await rootBundle.loadString('assets/data/radio.json');
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading radio: $e');
      return [];
    }
  }

  static Future<List<dynamic>> loadQA() async {
    try {
      final raw = await rootBundle.loadString('assets/data/qa.json');
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading qa: $e');
      return [];
    }
  }

    static Future<List<dynamic>> loadKidsStories() async {
    try {
      final raw = await rootBundle.loadString('assets/data/kids-stories.json');
      final List<dynamic> list = jsonDecode(raw);
      if (list.length >= 25) return list;
    } catch (_) {}
    return _fallbackKidsStories;
  }

  static final List<dynamic> _fallbackKidsStories = [
  {
    "id": 1,
    "title_ku": "گەشتی حەزرەتی نوح (س.خ)",
    "title_en": "Prophet Noah's Ark",
    "icon": "🚢",
    "color": "#FF6B6B",
    "lesson_ku": "پاداشتی گوێڕایەڵی خودا ڕزگاربوونە لە تەنگانەدا.",
    "lesson_en": "God's obedience brings rescue in difficult times.",
    "content_ku": "هەزاران ساڵ لەمەوبەر، خودای گەورە فەرمانی بە قەومی نوح کرد کە بگەڕێنەوە سەر ڕێگای ڕاست، بەڵام تەنها چەند کەسێکی کەم باوەڕیان هێنا. خودا فەرمانی بە نوح کرد کە کەشتییەکی گەورە دروست بکات. نوح جووتێک لە هەموو جۆرە ئاژەڵێکی خستە ناو کەشتییەکە. کاتێک بارانە لێزمەکە دەستی پێکرد، تەنها ئەوانەی ناو کەشتییەکە ڕزگاریان بوو.",
    "content_en": "Thousands of years ago, Prophet Noah called his people to the right path. When only a few believed, God commanded him to build a giant Ark. Noah took a pair of every animal into the ship. When the great flood began, only those inside the Ark were saved safely."
  },
  {
    "id": 2,
    "title_ku": "حەزرەتی یونس و نەهەنگەکە",
    "title_en": "Prophet Yunus & the Whale",
    "icon": "🐋",
    "color": "#4D96FF",
    "lesson_ku": "تەوبە و استغفار دەرگای داخراو دەکاتەوە.",
    "lesson_en": "Repentance and prayer open closed doors.",
    "content_ku": "حەزرەتی یونس لە قەومەکەی توڕە بوو و سواری کەشتییەک بوو بۆ ئەوەی بڕوات. لە ناو دەریاکەدا گەردەلوولێک دروست بوو و یونس کەوتە ناو ئاوەکە. نەهەنگێکی گەورە یونس-ی قووتدا. یونس لە ناو سکی نەهەنگەکەدا سێ شەو و سێ ڕۆژ تەنها یادی خودای دەکرد و دەیگوت: \"لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ\". خودا نزاەکەی قبوڵ کرد و نەهەنگەکە یونس-ی گەڕاندەوە بۆ وشکانی.",
    "content_en": "Prophet Yunus left his people and boarded a ship. A storm hit, and he was thrown into the sea. A giant whale swallowed him. Inside the whale, he prayed: \"There is no God but You, Glory be to You! I was among the wrongdoers.\" God accepted his prayer and the whale safely brought him back to land."
  },
  {
    "id": 3,
    "title_ku": "خەونەکەی حەزرەتی یوسف",
    "title_en": "Prophet Joseph's Dream",
    "icon": "👑",
    "color": "#FFD93D",
    "lesson_ku": "ئارامگرتن لەسەر ناخۆشی دەبێتە هۆی گەیشتن بە پلەی بەرز.",
    "lesson_en": "Patience in hardship leads to high status.",
    "content_ku": "یوسف منداڵ بوو کاتێک خەونی بینی کە ١١ ئەستێرە و خۆر و مانگ کڕنۆشی بۆ دەبەن. باوکی پێی گوت باسی ئەم خەونە بۆ براکانی نەکات. براکانی یوسف حەسوودیان پێدەبرد و خستیانە ناو بیرێکی قوڵەوە. بەڵام خودا یوسفی لە ناو بیرەکە پاراست و دوای چەندین ساڵ بوو بە گەورەی میسر و براکانی هاتنەوە بۆ لای.",
    "content_en": "Young Joseph dreamt that 11 stars, the sun, and the moon bowed to him. His father told him not to tell his brothers. His envious brothers threw him into a well, but God protected him. Years later, he became a leader in Egypt and his dreams came true."
  },
  {
    "id": 4,
    "title_ku": "چیڕۆکی فیلەکە و ئەبرەهە",
    "title_en": "The Year of the Elephant",
    "icon": "🐘",
    "color": "#6BCB77",
    "lesson_ku": "خودای گەورە ماڵەکەی خۆی (کەعبە) دەپارێزێت.",
    "lesson_en": "God protects His Sacred House (The Kaaba).",
    "content_ku": "پاشایەکی زاڵم هەبوو بە ناوی ئەبرەهە، ویستی کەعبە بڕووخێنێت بە فیلێکی گەورە. کاتێک گەیشتنە مەککە، فیلەکە دانیشت و نەدەڕۆیشتە پێشەوە. دواتر هەزاران باڵندە هاتن و بەردی بچووکیان تێگرتن و سوپاکەی ئەبرەهە لەناو چوون. ئەم ساڵە بە ساڵی فیل ناسراوە، کە تێیدا پێغەمبەرمان ﷺ لەدایک بوو.",
    "content_en": "A king named Abraha wanted to destroy the Kaaba with a giant elephant. When they reached Mecca, the elephant refused to move. Then, thousands of birds arrived and dropped stones on the army, defeating them. This is the Year of the Elephant, when Prophet Muhammad (PBUH) was born."
  },
  {
    "id": 5,
    "title_ku": "حەزرەتی ئیبراهیم و ئاگرەکە",
    "title_en": "Prophet Ibrahim & the Fire",
    "icon": "🔥",
    "color": "#FF9F29",
    "lesson_ku": "خودا بۆ ئەو کەسانەیە کە تەنها پشتی پێ دەبەستن.",
    "lesson_en": "God is for those who rely only on Him.",
    "content_ku": "حەزرەتی ئیبراهیم بە تەنها دژی بتەکان وەستا. خەڵکەکە زۆر توڕە بوون و بڕیاریاندا ئیبراهیم بسووتێنن. ئاگرێکی زۆر گەورەیان کردەوە و ئیبراهیمیان تێخست. بەڵام خودای گەورە فەرمانی بە ئاگرەکە کرد: \"ئەی ئاگر سارد و سەلامەت بێت بۆ ئیبراهیم\". ئاگرەکە هیچ زیانێکی بە ئیبراهیم نەگەیاند و بە سەلامەتی لێی هاتە دەرەوە.",
    "content_en": "Prophet Ibrahim stood against idols. The people threw him into a massive fire. But God commanded the fire: \"O fire, be cool and peaceful for Ibrahim.\" The fire did not burn him, and he walked out safely by God's miracle."
  },
  {
    "id": 6,
    "title_ku": "جاڵجاڵۆکەی ناو ئەشکەوتەکە",
    "title_en": "The Spider in the Cave",
    "icon": "🕸️",
    "color": "#7B1FA2",
    "lesson_ku": "خودا بە بچووکترین دروستکراوی خۆی دەتوانێت گەورەترین دوژمن لەناو ببات.",
    "lesson_en": "God can defeat the greatest enemy with His smallest creatures.",
    "content_ku": "کاتێک پێغەمبەر ﷺ و ئەبوبەکر خەریکی کۆچ بوون بۆ مەدینە، کافرەکان دوایان کەوتبوون. ئەوان چوونە ناو ئەشکەوتێک بۆ ئەوەی خۆیان بشارنەوە. خودای گەورە فەرمانی بە جاڵجاڵۆکەیەک کرد کە بە دەوری دەرگای ئەشکەوتەکەدا تەن بچنێت. کاتێک کافرەکان گەیشتنە سەر دەرگاکە، وایان زانی کەس لەوێ نییە چونکە تەنەکە نەپچڕابوو.",
    "content_en": "During the Hijri migration, Prophet Muhammad and Abu Bakr hid in a cave. God commanded a spider to weave a web over the cave entrance. When the enemies reached the entrance, they believed no one was inside because the web was untouched, and so they moved on."
  },
  {
    "id": 7,
    "title_ku": "حەزرەتی سلێمان و مێروولەکە",
    "title_en": "Prophet Solomon & the Ant",
    "icon": "🐜",
    "color": "#34495E",
    "lesson_ku": "خودای گەورە گوێی لە هەموو دروستکراوەکانیەتی، تەنانەت بچووکەکانیش.",
    "lesson_en": "God hears all His creatures, even the smallest ones.",
    "content_ku": "حەزرەتی سلێمان توانای قسەکردنی لەگەڵ ئاژەڵەکان هەبوو. ڕۆژێک لەگەڵ سوپاکەی دەڕۆیشت، گوێی لە دەنگی مێروولەیەک بوو کە بە هاوڕێکانی دەگوت: \"خێرا برۆنە ناو کونی خۆتان نەک سوپاکەی سلێمان بێ ئەوەی بزانن پانتان بکەنەوە\". سلێمان بەم قسەیە پێکەنی و سوپاکەی ڕاگرت تا مێروولەکان بە سەلامەتی بڕۆن.",
    "content_en": "Prophet Solomon could speak to animals. While marching with his army, he heard an ant tell its colony: \"Hide in your homes so Solomon's army doesn't step on you by mistake.\" Solomon smiled and stopped his army until the ants were safe."
  },
  {
    "id": 8,
    "title_ku": "وشترەکەی حەزرەتی ساڵح",
    "title_en": "Prophet Salih & the Camel",
    "icon": "🐪",
    "color": "#C0392B",
    "lesson_ku": "نابێت زیان بە دروستکراوەکانی خودا بگەیەنین.",
    "lesson_en": "We must not harm God's creatures.",
    "content_ku": "قەومی حەزرەتی ساڵح داوای موعجیزەیەکیان کرد. خودا وشترێکی گەورەی لە ناو بەردێکەوە بۆ ناردن. مەرجەکە ئەوە بوو کە زیانی پێنەگەیەنن و ڕۆژێک بۆ وشترەکە بێت و ڕۆژێک بۆ ئەوان بۆ ئاو خواردنەوە. بەڵام خەڵکە زاڵمەکە وشترەکەیان سەربڕی. خوداش بەهۆی ئەم تاوانەوە سزای دان.",
    "content_en": "Prophet Salih's people asked for a miracle. God brought a giant camel out of a rock. They were told to respect it and share the water. But the people harmed the camel, and as a result, God punished them for their cruelty."
  },
  {
    "id": 9,
    "title_ku": "حەزرەتی عیسا و باڵندەی قوڕین",
    "title_en": "Prophet Jesus & the Clay Bird",
    "icon": "🕊️",
    "color": "#AED6F1",
    "lesson_ku": "موعجیزە تەنها بە یارمەتی و ویستی خودایە.",
    "lesson_en": "Miracles happen only by the will of God.",
    "content_ku": "حەزرەتی عیسا یەکێک بوو لە پێغەمبەرە گەوران. ڕۆژێک پارچە قوڕێکی هێنا و شێوەی باڵندەیەکی لێ دروست کرد. پاشان بە فەرمانی خودای گەورە فووی پیادا کرد و باڵندەکە بوو بە باڵندەیەکی ڕاستەقینە و دەستی بە فڕین کرد. ئەمە نیشانەیەک بوو بۆ خەڵکەکە کە عیسا نێردراوی خودایە.",
    "content_en": "Prophet Jesus once took a piece of clay and shaped it into a bird. By the command of God, he breathed into it, and it turned into a real bird that flew away. This was a miracle showing that Jesus was a chosen Prophet of God."
  },
  {
    "id": 10,
    "title_ku": "حەزرەتی موسا و دەریاکە",
    "title_en": "Prophet Moses & the Sea",
    "icon": "🌊",
    "color": "#2ECC71",
    "lesson_ku": "کاتێک هەموو شتێک مەحاڵ دەردەکەوێت، خودا ڕێگایەک دەکاتەوە.",
    "lesson_en": "When things seem impossible, God opens a way.",
    "content_ku": "حەزرەتی موسا و خەڵکەکەی لە دەست فیرعەونی زاڵم ڕایانکرد. گەیشتنە بەردەم دەریایەکی گەورە و سوپای فیرعەون پشتیان بوو. خودا فەرمانی بە موسا کرد کە گۆچانەکەی بکێشێت بە دەریاکەدا. دەریاکە بوو بە دوو بەش و ڕێگایەکی وشک دروست بوو. موسا و خەڵکەکەی تێپەڕین و فیرعەون لە ناو ئاوەکەدا خنکا.",
    "content_en": "Prophet Moses and his people were trapped between Pharaoh's army and the Red Sea. God commanded Moses to strike the sea with his staff. The water split into two, creating a dry path. Moses and his people crossed safely while the army was defeated."
  },
  {
    "id": 11,
    "title_ku": "ئەصحابولکەهف (گه‌نجه‌کانی ئه‌شکه‌وت)",
    "title_en": "The People of the Cave",
    "icon": "⛰️",
    "color": "#795548",
    "lesson_ku": "خودای گەورە توانای بەسەر هەموو شتێکدا هەیە، تەنانەت ڕاگرتنی کاتیش.",
    "lesson_en": "God has power over everything, even stopping time.",
    "content_ku": "چەند گەنجێکی باوەڕدار لە دەست پاشایەکی زاڵم ڕایانکرد بۆ ناو ئەشکەوتێک. ئەوان لەوێ خەویان لێکەوت. خودای گەورە ئەوانی بۆ ماوەی ٣٠٩ ساڵ بە خەوتوویی هێشتمەوە! کاتێک هەستان، وایان زانی تەنها ڕۆژێک یان نیوە ڕۆژێک خەوتوون. ئەمە نیشانەیەک بوو بۆ خەڵکەکە کە خودا دەتوانێت مردووەکان زیندوو بکاتەوە.",
    "content_en": "Believing youths fled from a tyrant king to a cave. God caused them to sleep for 309 years! When they woke up, they thought only a day or part of a day had passed. This was a miraculous sign that God can bring the dead back to life."
  },
  {
    "id": 12,
    "title_ku": "خاوەن دوو باخەکە",
    "title_en": "The Two Gardens",
    "icon": "🍇",
    "color": "#8BC34A",
    "lesson_ku": "پێویستە هەمیشە سوپاسگوزاری خودا بین و تەکبور نەکەین.",
    "lesson_en": "We should always be thankful to God and avoid arrogance.",
    "content_ku": "پیاوێک دوو باخی زۆر جوانی هەبوو، فیز و شانازی بەسەر دراوسێکەیدا دەکرد و دەیگوت \"ئەم باخانە هەرگیز لەناو ناچن\". دراوسێکەی پێی گوت بڵێ \"ماشاء اللە\". بەڵام ئەو پیاوە گوێی نەگرت. دواتر خودا باخەکانی لەناو برد و پیاوەکە پەشیمان بووەوە، بەڵام ئیتر کات بەسەر چووبوو.",
    "content_en": "A man with two beautiful gardens was arrogant towards his neighbor, saying his wealth would last forever. His neighbor advised him to say \"MashaAllah,\" but he refused. Later, God destroyed the gardens, and the man regretted his pride, learning that everything belongs to God."
  },
  {
    "id": 13,
    "title_ku": "حەزرەتی زەکەریا و منداڵەکە",
    "title_en": "Prophet Zakariya’s Prayer",
    "icon": "✨",
    "color": "#E91E63",
    "lesson_ku": "هیچ شتێک بۆ خودا مەحاڵ نییە، تەنها دوعا بکە.",
    "lesson_en": "Nothing is impossible for God; just keep praying.",
    "content_ku": "حەزرەتی زەکەریا زۆر پیر ببوو و منداڵی نەبوو. ئەو زۆر حەزی دەکرد کوڕێکی هەبێت کە دوای ئەو خەڵک فێری ئایین بکات. لە کاتی نوێژدا هاواری کرد \"پەروەردگارم بە تەنیا جێم مەهێڵە\". خودای گەورە مژدەی پێدا کە کوڕێکی دەبێت بە ناوی (یەحیا). زەکەریا زۆر دڵخۆش بوو چونکە خودا دوعاکەی قبوڵ کرد.",
    "content_en": "Prophet Zakariya was very old and had no children. He prayed to God for a son to guide people in faith. While praying, he said: \"My Lord, do not leave me alone.\" God granted him a son named John (Yahya). Zakariya was overjoyed as God answered his long-awaited prayer."
  },
  {
    "id": 14,
    "title_ku": "حەزرەتی داود و ئاسنەکە",
    "title_en": "Prophet David & the Iron",
    "icon": "🛡️",
    "color": "#607D8B",
    "lesson_ku": "هەموو پێغەمبەرێک کاری کردووە و بە ڕەنجی شانی خۆیان ژیاون.",
    "lesson_en": "All Prophets worked hard and earned their own living.",
    "content_ku": "حەزرەتی داود پاشایەکی گەورە بوو، بەڵام هەمیشە کاری دەکرد. خودای گەورە ئاسنی بۆ ئەو نەرم کردبوو وەک هەویر! ئەو دەیتوانی بە دەستی خۆی زرێ و قەڵغان دروست بکات بۆ سوپاکەی بێ ئەوەی ئاگر بەکاربهێنێت. ئەو هەمیشە سوپاسی خودای دەکرد بۆ ئەو بەهرەیەی کە پێی بەخشراوە.",
    "content_en": "Prophet David was a powerful king but he always worked for his living. God made iron soft for him like dough! He could shape armor and shields with his hands without using fire. He was grateful for this special gift and used it to protect his people."
  },
  {
    "id": 15,
    "title_ku": "وشترە گریاوەکە",
    "title_en": "The Crying Camel",
    "icon": "🐪",
    "color": "#795548",
    "lesson_ku": "ئیسلام فەرمانمان پێ دەکات کە میهرەبان بین لەگەڵ ئاژەڵەکان.",
    "lesson_en": "Islam teaches us to be kind and merciful to animals.",
    "content_ku": "ڕۆژێک پێغەمبەر ﷺ چووە ناو باخێکی پیاوێکی ئەنساڕی. وشترێک لەوێ بوو، کاتێک پێغەمبەری بینی دەستی کرد بە گریان و فرمێسک لە چاوەکانی هاتە خوارێ. پێغەمبەر ﷺ چوو بۆ لای و دەستی بەسەردا هێنا تا ئارام بووەوە. پاشان بە خاوەنەکەی فەرموو: \"لە خودا بترسە بەرامبەر ئەم گیاندارە، چونکە سکاڵای لای من کرد کە برسی دەیکەیت و زۆر کاری پێ دەکەیت\".",
    "content_en": "One day, the Prophet ﷺ entered a garden and saw a camel. When the camel saw him, it began to cry. The Prophet ﷺ stroked it until it calmed down. He then told its owner: \"Fear God regarding this animal, for it complained to me that you starve it and overwork it.\""
  },
  {
    "id": 16,
    "title_ku": "حەزرەتی ئەیوب و ئارامگری",
    "title_en": "Prophet Ayyub & Patience",
    "icon": "🌸",
    "color": "#9C27B0",
    "lesson_ku": "ئارامگرتن لەسەر نەخۆشی و ناخۆشی پاداشتی گەورەی لای خودا هەیە.",
    "lesson_en": "Patience in illness and hardship earns great rewards from God.",
    "content_ku": "حەزرەتی ئەیوب زۆر دەوڵەمەند بوو و منداڵی زۆر بوو، بەڵام تووشی نەخۆشییەکی سەخت بوو و تاقیکرایەوە. تەندروستی و ماڵ و سامانەکەی لەدەستدا. لەگەڵ ئەوەشدا تەنها ئارامی دەگرت و بەردەوام سوپاسی خودای دەکرد. دوای چەندین ساڵ لە ئارامگری، خودای گەورە شیفای کامل دایەوە و تەمەن و مال و منداڵی زیاتری پێ بەخشییەوە.",
    "content_en": "Prophet Ayyub was blessed with wealth and family, but he was tested with a severe illness. He lost his health and wealth, yet he remained patient and thankful to God. After years of patience, God healed him completely and restored all his blessings doubled."
  },
  {
    "id": 17,
    "title_ku": "سەدەقەکەی حەزرەتی عائیشە",
    "title_en": "Lady Aishah's Generosity",
    "icon": "🎁",
    "color": "#FF4081",
    "lesson_ku": "بەخشین لە کاتی پێویستیدا لای خودای گەورە زۆر خۆشەویستە.",
    "lesson_en": "Giving charity in times of need is deeply beloved to God.",
    "content_ku": "ڕۆژێک حەزرەتی عائیشە بەڕۆژوو بوو. هەژارێک هاتە دەرگاکەیان و داوای خۆراکی کرد بۆ ڕزگاربوون لە برسییەتی. لە ماڵەکەدا تەنها یەک پارچە نانی وشک هەبوو بۆ بەربانگ. عائیشە بێ دوودڵی نانەکەی بەخشی بە هەژارەکە. کاتێک ئیوارە هات، یەکێک دیارییەکی گۆشتی برژاوی گەرمی بۆ ناردن! عائیشە ڕوونی کردەوە کە خودا بەرەکەت دەخاتە ناو سەدەقەوە.",
    "content_en": "One day, Lady Aishah was fasting. A poor man knocked on her door asking for food. She only had a single piece of bread for Iftar, but she gave it to the man. At sunset, a neighbor unexpectedly sent her a dish of roasted meat! She reminded everyone that charity never decreases wealth."
  },
  {
    "id": 18,
    "title_ku": "تینوویەتی سەگەکە و لێخۆشبوون",
    "title_en": "The Thirsty Dog & Forgiveness",
    "icon": "🐕",
    "color": "#FF9800",
    "lesson_ku": "میهرەبانی بەرامبەر دروستکراوە بێدەسەڵاتەکان گوناهەکان دەسڕێتەوە.",
    "lesson_en": "Kindness to helpless animals wipes away sins.",
    "content_ku": "پیاوێک لە بیابانێکی گەرمدا زۆر تینووی ببوو. چوو بۆ ناو بیرێک و ئاوی خواردەوە. کاتێک هاتە دەرەوە سەگێکی بینی کە لە تاو تینوویەتی خاکی تەڕی دەلیستەوە. پیاوەکە بە بەزەیییەوە دیسان چووەوە ناو بیرەکە، پێڵاوەکەی پڕکرد لە ئاو و هێنای بۆ سەگەکە تا تێربوو. خودای گەورە سوپاسی ئەم کارەی کرد و لە گوناهەکانی خۆشبوو.",
    "content_en": "A man in a hot desert was extremely thirsty. He climbed down a well to drink water. When he came up, he saw a thirsty dog licking wet sand. Feeling mercy, he climbed down again, filled his leather shoe with water, and quenched the dog's thirst. God appreciated his deed and forgave him."
  },
  {
    "id": 19,
    "title_ku": "کۆچەکەی هاجەر و بیرە پیرۆزەکەی زمزم",
    "title_en": "Hajar & the Well of Zamzam",
    "icon": "🏺",
    "color": "#00BCD4",
    "lesson_ku": "پشت بەستن بە خودا هەرگیز بێئومێدیت ناکات.",
    "lesson_en": "Trusting in God never leaves a believer hopeless.",
    "content_ku": "حەزرەتی ئیبراهیم هاوسەرەکەی (هاجەر) و منداڵە ساواکەی (ئیسماعیل) لە بیابانی چۆڵی مەککە بەجێهێشت بە فەرمانی خودا. کاتێک ئاوەکەیان تەواو بوو، هاجەر ٧ جار لە نێوان گردی سەفا و مەڕوەدا ڕایکرد بۆ گەڕان بەدوای ئاودا. بە موعجیزەی خودای گەورە، لە ژێر پێی ئیسماعیلی ساوا کانییەکی پڕ لە ئاوی (زمزم) هەڵقوڵا کە تا ئێستاش ڕەوانە.",
    "content_en": "Prophet Ibrahim left his wife Hajar and baby Ishmael in the dry desert of Mecca by God's command. When their water ran out, Hajar ran 7 times between Safa and Marwah hills searching for water. By God's miracle, the spring of Zamzam burst under baby Ishmael's feet, flowing to this day."
  },
  {
    "id": 20,
    "title_ku": "سۆزی پێغەمبەر ﷺ بۆ منداڵان",
    "title_en": "The Prophet's Love for Children",
    "icon": "👶",
    "color": "#8E24AA",
    "lesson_ku": "خۆشەویستی و میهرەبانی بۆ منداڵان ڕەوشتی بەرزی پێغەمبەرایەتییە.",
    "lesson_en": "Loving and nurturing children is a noble prophetic character.",
    "content_ku": "پێغەمبەرمان ﷺ زۆر بەسۆز و میهرەبان بوو لەگەڵ منداڵاندا. کاتێک نوێژی دەکرد، حەسەن و حوسێن (نەوا بچووکەکانی) دەهاتنە سەر پشتی لە کاتی سوجدەدا، پێغەمبەر ﷺ سوجدەکەی درێژ دەکردەوە تا منداڵەکان بە دڵی خۆیان دابەزن. هەروەها کاتێک دەچووە نێو شار، دەستی بەسەر سەری منداڵاندا دەهێنا و بە زەردەخەنەوە سڵاوی لێدەکردن.",
    "content_en": "Prophet Muhammad ﷺ was deeply loving towards children. While he prayed, his young grandsons Hasan and Husayn would climb on his back during prostration, and he would prolong the prostration so as not to disturb them. He always greeted children with warm smiles and kindness."
  },
  {
    "id": 21,
    "title_ku": "داری دارخورما گریاوەکە",
    "title_en": "The Crying Date-Palm Tree",
    "icon": "🌴",
    "color": "#4CAF50",
    "lesson_ku": "خۆشەویستی بۆ پێغەمبەر ﷺ لە دڵی گشت دروستکراوەکاندایە.",
    "lesson_en": "Love for Prophet Muhammad (PBUH) resides in all creation.",
    "content_ku": "لە مزگەوتی پێغەمبەردا ﷺ، قەدی دارخورمایەک هەبوو کە پێغەمبەر ﷺ لە کاتی وتار خوێندنەوەدا پشتی پێ دەبەست. کاتێک منبەرێکی دارینیان دروست کرد و پێغەمبەر چووە سەر منبەرە نوێیەکە، داری دارخورماکە لە تاو دوورکەوتنەوەی پێغەمبەر وەک منداڵێکی بچووک دەستی کرد بە گریان! پێغەمبەر ﷺ هاتە خوارەوە و دەستی بەسەردا هێنا تا ئارام بووەوە.",
    "content_en": "In the Prophet's Mosque, a date-palm trunk served as his support during sermons. When a new wooden pulpit was built and the Prophet moved to it, the trunk began to weep out loud like a child missing him. The Prophet ﷺ descended and hugged the trunk until it calmed down."
  },
  {
    "id": 22,
    "title_ku": "ڕاستگۆیی عەبدولقادری گەیلانی",
    "title_en": "The Honest Boy & the Robbers",
    "icon": "🎒",
    "color": "#3F51B5",
    "lesson_ku": "ڕاستگۆیی هۆکاری ڕزگاربوونە تەنانەت لەگەڵ سەخترین دوژمنیشدا.",
    "lesson_en": "Honesty brings salvation even among dangerous enemies.",
    "content_ku": "عەبدولقادر منداڵ بوو کاتێک دایکی ٤٠ دیناری لە ناو جڵەکانیدا دوورییەوە و وەسیەتی پێکرد کە هەرگیز درۆ نەکات. لە ڕێگادا جەردەکان پەلاماری کاروانەکەیاندا. کاتێک لە عەبدولقادریان پرسی کە چی پێیە، گوتی ٤٠ دینارم پێیە! سەرۆکی جەردەکان سەری سوڕما کە بۆچی درۆی نەکرد. عەبدولقادر گوتی پەیمانم بە دایکم داوە درۆ نەکەم. سەرۆکی جەردەکان لەسەر دەستی تائەب بووەوە.",
    "content_en": "Young Abdul-Qadir set off on a journey. His mother sowed 40 coins into his coat and advised him never to lie. Highway robbers attacked the caravan and asked him what he had. He honestly admitted he had 40 coins. Surprised by his truthfulness, the leader repented and gave up robbery."
  },
  {
    "id": 23,
    "title_ku": "خزمەتکردنی دایک (حەزرەتی وەیس)",
    "title_en": "Uwais al-Qarani & His Mother",
    "icon": "👵",
    "color": "#E91E63",
    "lesson_ku": "خزمەتکردنی دایک و باوک کلیلی بەدەستهێنانی ڕەزامەندی خودایە.",
    "lesson_en": "Serving one's parents is a direct path to God's pleasure.",
    "content_ku": "وەیسی قەرەنی گەنجێک بوو لە یەمەن کە زۆر حەزی دەکرد پێغەمبەر ﷺ ببێنێت، بەڵام دایکێکی پەککەوتەی هەبوو کە نەیدەتوانی بەجێی بهێڵێت. وەیس بڕیاریدا لە لای دایکی بمێنێتەوە و خزمەتی بکات. پێغەمبەر ﷺ بە هاوەڵانی فەرموو: \"وەیس بەهۆی چاکەکاریی و خزمەتکردنی دایکی، دوعاکانی لای خودا بەرز و قبوڵکراون\".",
    "content_en": "Uwais al-Qarani was a young man in Yemen who longed to meet Prophet Muhammad ﷺ, but he stayed behind to care for his elderly, disabled mother. The Prophet ﷺ praised him to his companions, saying: \"Because of his devotion to his mother, Uwais's prayers are answered by God.\""
  },
  {
    "id": 24,
    "title_ku": "ئەش کەوتی سێ پیاوەکە",
    "title_en": "The Three Men Trapped in a Cave",
    "icon": "🗿",
    "color": "#673AB7",
    "lesson_ku": "کردەوەی چاک و دڵسۆزانە بۆ خودا تەنگانەکان لادەبات.",
    "lesson_en": "Pure deeds done solely for God open paths out of distress.",
    "content_ku": "سێ پیاو لە ئەشکەوتێکدا گیریان خوارد کاتێک بەردێکی زۆر گەورە کەوتە سەر دەرگاکەی. ئەوان ڕێککەوتن کە بە چاکترین کردەوەی دەروونی خۆیان دوعا لە خودا بکەن. یەکێکیان باسی ڕێزگرتن لە دایک و باوکی کرد، دووەمیان باسی داوێنپاکی، سێیەمیان باسی دڵسۆزی لە پێدانی حەقی کرێکار. بە وەسیلەی هەر دوعایەک بەردەکە جوڵا تا ڕزگاریان بوو.",
    "content_en": "Three men were trapped inside a cave when a huge boulder blocked the entrance. They agreed to pray to God by mentioning their purest good deeds. One mentioned honoring his parents, another avoiding temptation, and the third paying a worker fairly. With each prayer, the rock shifted until they escaped."
  },
  {
    "id": 25,
    "title_ku": "دوعای بارانبارینی مێروولەکە",
    "title_en": "Prophet Solomon & the Praying Ant",
    "icon": "🌧️",
    "color": "#0288D1",
    "lesson_ku": "دوعای گشت دروستکراوەکانی خودا بیستراوە و نرخی هەیە.",
    "lesson_en": "The prayers of all creation are heard and valued by God.",
    "content_ku": "لە کاتی وشکەساڵیدا، حەزرەتی سلێمان خەڵکەکەی برد بۆ دەرەوە بۆ دوعای بارانبارین. لە ڕێگادا مێروولەیەکی بینی کە سەرەوژێر لەسەر زەوی پاڵکەوتبوو و دەستەکانی بەرەو ئاسمان بەرز کردبووەوە و دوعای بارانی دەکرد. سلێمان بە سوپاکەی فەرموو گەڕێنەوە، چونکە بەهۆی دوعای دڵسۆزانەی ئەم مێروولەیەوە باران دەبارێت!",
    "content_en": "During a drought, Prophet Solomon led his people to pray for rain. On the way, he saw an ant lying on its back with its legs raised to the sky, praying to God for rain. Solomon turned to his people and said: \"Return home, for rain will fall due to the sincere prayer of this ant!\""
  }
];


  static Future<List<dynamic>> loadHajjGuide() async {
    try {
      final raw = await rootBundle.loadString('assets/data/hajj.json');
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading hajj guide: $e');
      return [];
    }
  }

  static Future<List<dynamic>> loadReciters() async {
    try {
      final raw = await rootBundle.loadString('assets/data/reciters.json');
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading reciters: $e');
      return [];
    }
  }

  static Future<List<dynamic>> loadPraySteps() async {
    try {
      final raw = await rootBundle.loadString('assets/data/pray_steps.json');
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading pray steps: $e');
      return [];
    }
  }

  static Future<List<dynamic>> loadPrayTypes() async {
    try {
      final raw = await rootBundle.loadString('assets/data/pray_types.json');
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading pray types: $e');
      return [];
    }
  }

  static Future<List<dynamic>> loadEvents() async {
    try {
      final raw = await rootBundle.loadString('assets/data/events.json');
      return jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading events: $e');
      return [];
    }
  }

  static final List<Map<String, dynamic>> _fallbackDailyVerses = [
    {
      'id': 1,
      'ar': 'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا ۝ وَيَرْزُقْهُ مِنْ حَيْثُ لَا يَحْتَسِبُ',
      'ku': 'هەر کەسێک لە خودا بترسێت، دەرچەی بۆ دروست دەکات و لە شوێنێکەوە ڕزقی دەدات کە بیری لێ ناکاتەوە.',
      'en': 'And whoever fears Allah - He will make for him a way out and provide for him from where he does not expect.',
      'ref': 'الطلاق: ٢-٣',
      'surah_number': 65,
      'ayah_number': 2,
    },
    {
      'id': 2,
      'ar': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا',
      'ku': 'بەڕاستی لەگەڵ هەر ناڕەحەتییەک ئاسانییەک هەیە، بە دڵنیاییەوە لەگەڵ هەر ناڕەحەتییەک ئاسانییەک هەیە.',
      'en': 'For indeed, with hardship [will be] ease. Indeed, with hardship [will be] ease.',
      'ref': 'الشرح: ٥-٦',
      'surah_number': 94,
      'ayah_number': 5,
    },
    {
      'id': 3,
      'ar': 'الَّذِينَ آمَنُوا وَتَطْمَئِنُّ قُلُوبُهُم بِذِكْرِ اللَّهِ ۗ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      'ku': 'ئەوانەی باوەڕیان هێناوە و دڵەکانیان بە یادی خودا دەحەسێتەوە؛ ئاگادار بن تەنها بە یادی خودا دڵەکان ئارام دەگرن.',
      'en': 'Those who have believed and whose hearts are assured by the remembrance of Allah. Unquestionably, by the remembrance of Allah hearts are assured.',
      'ref': 'الرعد: ٢٨',
      'surah_number': 13,
      'ayah_number': 28,
    },
  ];

  static final List<Map<String, dynamic>> _fallbackSunnahs = [
    {
      "id": 1,
      "icon": "🌙",
      "ku": "پێش خەوتن دەستنوێژ بگرە و لەسەر لای ڕاست بخەوە.",
      "ar": "توضأ قبل النوم ونَمْ على شقك الأيمن.",
      "en": "Perform Wudu before sleeping and sleep on your right side.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 2,
      "icon": "📖",
      "ku": "پێش خەوتن سورەتی (المُلک) بخوێنە؛ پارێزگاریت لە سزای گۆڕ دەکات.",
      "ar": "اقرأ سورة الملك قبل النوم؛ فإنها تنجي من عذاب القبر.",
      "en": "Recite Surah Al-Mulk before sleeping; it protects from the punishment of the grave.",
      "source_ku": "سنن الترمذي",
      "source_ar": "سنن الترمذي",
      "source_en": "Sunan At-Tirmidhi",
    },
    {
      "id": 3,
      "icon": "🤲",
      "ku": "بە دەستی ڕاستت خواردن بخۆ و لەوەی بەرامبەرت بخۆ.",
      "ar": "سَمِّ الله وكُل بيمينك وكُل مما يليك.",
      "en": "Say Bismillah, eat with your right hand, and eat from what is in front of you.",
      "source_ku": "متفق عليه",
      "source_ar": "متفق عليه",
      "source_en": "Bukhari & Muslim",
    },
    {
      "id": 4,
      "icon": "🏠",
      "ku": "کاتێک دەچیتە ژوورەوە بۆ ماڵەوە (بِسْمِ اللَّهِ) بڵێ؛ شەیتان ناتوانێت لەگەڵتدا بێتە ژوورەوە.",
      "ar": "قل (بسم الله) عند دخول المنزل؛ حتى لا يدخل الشيطان معك.",
      "en": "Say 'Bismillah' when entering your home so Shaytan cannot enter with you.",
      "source_ku": "صحيح مسلم",
      "source_ar": "صحيح مسلم",
      "source_en": "Sahih Muslim",
    },
    {
      "id": 5,
      "icon": "🪥",
      "ku": "پێش هەر نوێژێک مسواک/سیواک بەکاربهێنە؛ دەم و ددان پاک دەکاتەوە و ڕەزامەندی پەروەردگاری تێدایە.",
      "ar": "استعمل السواك عند كل صلاة؛ فإنه مطهرة للفم مرضاة للرب.",
      "en": "Use Miswak before every prayer; it cleanses the mouth and pleases the Lord.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 6,
      "icon": "☀️",
      "ku": "دوو ڕەکاتی سوننەتی بەیانی مەهێڵە؛ لە دونیا و هەرچی تێدایەتی باشترە.",
      "ar": "لا تترك ركعتي الفجر؛ فهما خير من الدنيا وما فيها.",
      "en": "Never leave the two Sunnah rakats of Fajr; they are better than the world and all in it.",
      "source_ku": "صحيح مسلم",
      "source_ar": "صحيح مسلم",
      "source_en": "Sahih Muslim",
    },
    {
      "id": 7,
      "icon": "🤝",
      "ku": "بە ڕووی خۆش و زەردەخەنەوە لە برای موسڵمانت بڕوانە؛ زەردەخەنەکەت سەدەقەیە.",
      "ar": "تبسمك في وجه أخيك صدقة.",
      "en": "Smiling in the face of your brother is charity.",
      "source_ku": "سنن الترمذي",
      "source_ar": "سنن الترمذي",
      "source_en": "Sunan At-Tirmidhi",
    },
    {
      "id": 8,
      "icon": "🌿",
      "ku": "ڕۆژانە ١٠٠ جار بڵێ: (سُبْحَانَ اللَّهِ وَبِحَمْدِهِ)؛ گوناهەکانت دەسڕدرێنەوە ئەگەرچی وەک کەفی دەریاش زۆر بن.",
      "ar": "قل (سبحان الله وبحمده) مائة مرة؛ تُحَطّ خطاياك وإن كانت مثل زبد البحر.",
      "en": "Say 'SubhanAllah wa bihamdihi' 100 times daily; your sins will be forgiven even if like sea foam.",
      "source_ku": "متفق عليه",
      "source_ar": "متفق عليه",
      "source_en": "Bukhari & Muslim",
    },
    {
      "id": 9,
      "icon": "🕌",
      "ku": "دواى هەر نوێژێکی فەرز ئایەتی فەرز (ئایەت ئەلکرسی) بخوێنە؛ هیچ شتێک لە نێوان تۆ و بەهەشتدا نامێنێت تەنها مردن نەبێت.",
      "ar": "اقرأ آية الكرسي دبر كل صلاة مكتوبة؛ لم يمنعك من دخول الجنة إلا أن تموت.",
      "en": "Recite Ayat Al-Kursi after every obligatory prayer; nothing prevents you from Paradise except death.",
      "source_ku": "سنن النسائي",
      "source_ar": "سنن النسائي",
      "source_en": "Sunan An-Nasa'i",
    },
    {
      "id": 10,
      "icon": "🌅",
      "ku": "بەیانیان و ئێواران زیکرەکانی بەیانیان و ئێواران بڵێ: (اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا).",
      "ar": "حافظ على أذكار الصباح والمساء: (اللهم بك أصبحنا وبك أمسينا).",
      "en": "Recite morning and evening remembrance: 'Allahumma bika asbahna wa bika amsayna'.",
      "source_ku": "سنن أبي داود",
      "source_ar": "سنن أبي داود",
      "source_en": "Sunan Abu Dawud",
    },
    {
      "id": 11,
      "icon": "🧹",
      "ku": "ئازار و ڕێگری لە ڕێگەی موسڵمانان دوور بخەرەوە؛ ئەوە پاداشتێکی گەورە و سەدەقەیە.",
      "ar": "إماطة الأذى عن الطريق صدقة.",
      "en": "Removing harmful objects from the path is charity.",
      "source_ku": "صحيح مسلم",
      "source_ar": "صحيح مسلم",
      "source_en": "Sahih Muslim",
    },
    {
      "id": 12,
      "icon": "💧",
      "ku": "لە کاتی دەستنوێژگرتندا دەست بە زێدەڕۆیی (سراف) مەکە لە ئاودا، ئەگەر لەسەر ڕووبارێکی ڕەوان بایت.",
      "ar": "لا تسرف في الماء ولو كنت على نهر جَارٍ.",
      "en": "Do not waste water while performing Wudu, even if you are at a flowing river.",
      "source_ku": "سنن ابن ماجه",
      "source_ar": "سنن ابن ماجه",
      "source_en": "Sunan Ibn Majah",
    },
    {
      "id": 13,
      "icon": "✨",
      "ku": "ڕۆژانە ١٢ ڕەکات سوننەتی ڕەواتب (پێش و دوای نوێژە فەرزەکان) بکە؛ خودا ماڵێکت لە بەهەشتدا بۆ دروست دەکات.",
      "ar": "صلِّ اثنتي عشرة ركعة تطوعاً في اليوم والليلة؛ يبنِ الله لك بيتاً في الجنة.",
      "en": "Pray 12 Voluntary Sunnah rakats daily; Allah will build a house for you in Paradise.",
      "source_ku": "صحيح مسلم",
      "source_ar": "صحيح مسلم",
      "source_en": "Sahih Muslim",
    },
    {
      "id": 14,
      "icon": "🤲",
      "ku": "دوعای نێوان بانگ و ئیقامە ڕەت ناکرێتەوە؛ لەو کاتەدا دوعا زۆر بکە.",
      "ar": "الدعاء لا يُرَدُّ بين الأذان والإقامة؛ فأكثروا من الدعاء.",
      "en": "Supplication made between Adhan and Iqamah is not rejected.",
      "source_ku": "سنن الترمذي",
      "source_ar": "سنن الترمذي",
      "source_en": "Sunan At-Tirmidhi",
    },
    {
      "id": 15,
      "icon": "🌙",
      "ku": "دووشەممە و پێنجشەممە بەڕۆژوو بە؛ کردارەکانی بەندە لەو دوو ڕۆژەدا بەرز دەکرێنەوە بۆ لای خودا.",
      "ar": "صُم يومي الاثنين والخميس؛ تعرض فيهما الأعمال على الله.",
      "en": "Fast on Mondays and Thursdays; deeds are presented to Allah on these days.",
      "source_ku": "سنن الترمذي",
      "source_ar": "سنن الترمذي",
      "source_en": "Sunan At-Tirmidhi",
    },
    {
      "id": 16,
      "icon": "📜",
      "ku": "ڕۆژی جومعە سورەتی (الکَھف) بخوێنە؛ ڕووناکییەکت بۆ درەوشاوە دەکات لە نێوان دوو جومعەدا.",
      "ar": "اقرأ سورة الكهف يوم الجمعة؛ أضاء لك من النور ما بين الجمعتين.",
      "en": "Recite Surah Al-Kahf on Friday; it illuminates light for you between the two Fridays.",
      "source_ku": "مستدرك الحاكم",
      "source_ar": "مستدرك الحاكم",
      "source_en": "Mustadrak Al-Hakim",
    },
    {
      "id": 17,
      "icon": "🥣",
      "ku": "پێش بەڕۆژووبوون نانی پاشیو (سەحوری) بخۆ؛ پاشیوکردن بەرەکەتی تێدایە.",
      "ar": "تسحروا؛ فإن في السحور بركة.",
      "en": "Eat Suhoor before fasting; indeed there is blessing in Suhoor.",
      "source_ku": "متفق عليه",
      "source_ar": "متفق عليه",
      "source_en": "Bukhari & Muslim",
    },
    {
      "id": 18,
      "icon": "🌴",
      "ku": "بە خورما یان ئاو بەڕۆژووبوونەکەت بشکێنە (ئيفطار بکە).",
      "ar": "إفطار الصائم على تمر أو ماء.",
      "en": "Break your fast with dates or water.",
      "source_ku": "سنن أبي داود",
      "source_ar": "سنن أبي داود",
      "source_en": "Sunan Abu Dawud",
    },
    {
      "id": 19,
      "icon": "🤍",
      "ku": "دڵی ئارام بدارە و تووڕە مەبە؛ پێغەمبەر ﷺ فەرمووی: (لا تَغْضَبْ - تووڕە مەبە).",
      "ar": "لا تغضب ولك الجنة.",
      "en": "Do not become angry; the Prophet ﷺ repeatedly advised: 'Do not be angry'.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 20,
      "icon": "💎",
      "ku": "فێری زیکری (لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ) بە؛ گەنجینەیەکە لە گەنجینەکانی بەهەشت.",
      "ar": "أكثر من قول (لا حول ولا قوة إلا بالله)؛ فإنها كنز من كنوز الجنة.",
      "en": "Recite 'La hawla wa la quwwata illa billah' often; it is a treasure from Paradise.",
      "source_ku": "متفق عليه",
      "source_ar": "متفق عليه",
      "source_en": "Bukhari & Muslim",
    },
    {
      "id": 21,
      "icon": "⭐",
      "ku": "بناغەکانی ئیسلام بەپێی ٥ پایە ڕابگرە: شەهادەت، نوێژ، زەکات، ڕۆژوو، و حەج.",
      "ar": "بُني الإسلام على خمس: شهادة أن لا إله إلا الله، وإقام الصلاة، وإيتاء الزكاة، وصوم رمضان، وحج البيت.",
      "en": "Islam is built on five pillars: Shahada, Prayer, Zakat, Fasting, and Hajj.",
      "source_ku": "متفق عليه",
      "source_ar": "متفق عليه",
      "source_en": "Bukhari & Muslim",
    },
    {
      "id": 22,
      "icon": "📣",
      "ku": "کاتێک گوێت لە بانگبوو، وەڵامی بانگبێژ بدەرەوە بە دووبارەکردنەوەی هەمان وشەکانی.",
      "ar": "إذا سمعتم النداء فقولوا مثل ما يقول المؤذن.",
      "en": "When you hear the Adhan, repeat the words of the muezzin.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 23,
      "icon": "🛡️",
      "ku": "سورەتەکانی (الإخلاص، الفلق، الناس) بەیانیان و ئێواران ٣ جار بخوێنە؛ لە هەموو خراپەیەک دەپارێزێت.",
      "ar": "اقرأ المعوذات ثلاث مرات صباحاً ومساءً؛ تكفيك من كل شيء.",
      "en": "Recite Surah Al-Ikhlas, Al-Falaq, and An-Nas 3 times morning and evening for protection.",
      "source_ku": "سنن أبي داود",
      "source_ar": "سنن أبي داود",
      "source_en": "Sunan Abu Dawud",
    },
    {
      "id": 24,
      "icon": "🕌",
      "ku": "لە کاتی چوونە ژوورەوە بۆ مزگەوت بە پێی ڕاست بچۆ ژوورەوە و دوعای چوونە ژوورەوەی مزگەوت بخوێنە.",
      "ar": "ادخل المسجد برجلك اليمنى وقل: (اللهم افتح لي أبواب رحمتك).",
      "en": "Enter the mosque with your right foot and say: 'Allahumma iftah li abwaba rahmatik'.",
      "source_ku": "سنن ابن ماجه",
      "source_ar": "سنن ابن ماجه",
      "source_en": "Sunan Ibn Majah",
    },
    {
      "id": 25,
      "icon": "🥤",
      "ku": "بە دانیشتنەوە ئاو بخۆرەوە و لە ٣ پشوودا (سێ هەناسە) ئاوەکە بخۆرەوە.",
      "ar": "اشرب الماء جالساً وعلى ثلاثة أنفاس.",
      "en": "Drink water while sitting down and in three separate breaths.",
      "source_ku": "صحيح مسلم",
      "source_ar": "صحيح مسلم",
      "source_en": "Sahih Muslim",
    },
    {
      "id": 26,
      "icon": "💖",
      "ku": "لە شەو و ڕۆژی جومعەدا زۆر دروود و سەلام لەسەر پێغەمبەر ﷺ بنێرە.",
      "ar": "أكثروا من الصلاة عليّ ليلة الجمعة ويوم الجمعة.",
      "en": "Send abundant salutations upon the Prophet ﷺ on the night and day of Friday.",
      "source_ku": "سنن ابن ماجه",
      "source_ar": "سنن ابن ماجه",
      "source_en": "Sunan Ibn Majah",
    },
    {
      "id": 27,
      "icon": "🍽️",
      "ku": "کاتێک دەست بە خواردن دەکەیت بڵێ: (بِسْمِ اللَّهِ)، ئەگەر لە بیرت چوو بڵێ: (بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ).",
      "ar": "سم الله في أول الطعام، فإن نسيت فقل: (بسم الله أوله وآخره).",
      "en": "Say 'Bismillah' at start of eating; if forgotten, say 'Bismillahi awwalahu wa akhirahu'.",
      "source_ku": "سنن أبي داود",
      "source_ar": "سنن أبي داود",
      "source_en": "Sunan Abu Dawud",
    },
    {
      "id": 28,
      "icon": "🌤️",
      "ku": "نوێژی چاشت (الضحى) بکە (٢ تا ٨ ڕەکات)؛ ئەوە وەکو سەدەقەی هەموو جومگەکانی جەستەت هەژمار دەکرێت.",
      "ar": "صلِّ صلاة الضحى؛ فإنها صدقة عن كل مَفْصِل من مفاصلك.",
      "en": "Pray Duha prayer; it serves as charity for every joint in your body.",
      "source_ku": "صحيح مسلم",
      "source_ar": "صحيح مسلم",
      "source_en": "Sahih Muslim",
    },
    {
      "id": 29,
      "icon": "⚖️",
      "ku": "دوو زیکر هەن سووکن لەسەر زمان، قورسن لەسەر تەرازوو، خۆشەویستن لای خودا: (سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ).",
      "ar": "كلمتان خفيفتان على اللسان ثقيلتان في الميزان حبيبتان إلى الرحمن: (سبحان الله وبحمده، سبحان الله العظيم).",
      "en": "Two words light on tongue, heavy on scales, loved by Ar-Rahman: 'SubhanAllah wa bihamdihi, SubhanAllahil-Adheem'.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 30,
      "icon": "🤝",
      "ku": "تەوقە (تەصافوح) لەگەڵ برای موسڵمانت بکە؛ گوناهەکانتان دەوەرێن وەکو گەڵای دار.",
      "ar": "صافح أخاك المسلم عند اللقاء؛ تُحَطّ خطاياكما كما تتساقط أوراق الشجر.",
      "en": "Shake hands when meeting your brother; your sins drop off like dry leaves off a tree.",
      "source_ku": "سنن الترمذي",
      "source_ar": "سنن الترمذي",
      "source_en": "Sunan At-Tirmidhi",
    },
    {
      "id": 31,
      "icon": "🌃",
      "ku": "دوایین نوێژی شەوت بکە بە نوێژی وتر.",
      "ar": "اجعلوا آخر صلاتكم بالليل وتراً.",
      "en": "Make Witr your last prayer of the night.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 32,
      "icon": "👋",
      "ku": "پێش دەستپێکردنی قسەکردن سەلام بکە: (السَّلَامُ عَلَیْكُمْ).",
      "ar": "السلام قبل الكلام.",
      "en": "Initiate greeting with 'Assalamu Alaikum' before speaking.",
      "source_ku": "سنن الترمذي",
      "source_ar": "سنن الترمذي",
      "source_en": "Sunan At-Tirmidhi",
    },
    {
      "id": 33,
      "icon": "🚪",
      "ku": "کاتێک لە ماڵ دەچیتە دەرەوە بڵێ: (بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ).",
      "ar": "قل عند الخروج من البيت: (بسم الله توكلت على الله ولا حول ولا قوة إلا بالله).",
      "en": "When leaving home, say: 'Bismillahi, tawakkaltu 'alallah, wa la hawla wa la quwwata illa billah'.",
      "source_ku": "سنن أبي داود",
      "source_ar": "سنن أبي داود",
      "source_en": "Sunan Abu Dawud",
    },
    {
      "id": 34,
      "icon": "👟",
      "ku": "لە کاتی پێڵاو لەپێکردندا بە پێی ڕاست دەست پێ بکە، و لە کاتی داكەنیندا بە پێی چەپ.",
      "ar": "إذا انتعل أحدكم فليبدأ باليمين، وإذا نزع فليبدأ بالشمال.",
      "en": "Put on your right shoe first, and take off your left shoe first.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 35,
      "icon": "🤧",
      "ku": "کاتێک پشکژمیت (پژمیت) بڵێ: (الْحَمْدُ لِلَّهِ).",
      "ar": "إذا عطس أحدكم فليقل: (الحمد لله).",
      "en": "Say 'Alhamdulillah' when you sneeze.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 36,
      "icon": "💬",
      "ku": "کاتێک کەسێک پژمی و گوتی (الحمد لله)، بڵێ: (یَرْحَمُكَ اللَّهُ).",
      "ar": "إذا عطس فحمد الله فقولوا له: (يرحمك الله).",
      "en": "Say 'Yarhamukallah' to someone who sneezes and says 'Alhamdulillah'.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 37,
      "icon": "🛌",
      "ku": "لەسەر لای ڕاست بخەوە و دەستی ڕاستت بخەرە ژێر ڕوومەتی ڕاستت.",
      "ar": "اضطجع على شقك الأيمن وضع يدك اليمنى تحت خدك الأيمن.",
      "en": "Sleep on your right side and place your right hand under your right cheek.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 38,
      "icon": "🥛",
      "ku": "بە پێوە (ڕاوەستاوەیی) ئاو مەخۆرەوە؛ بە دانیشتنەوە ئاوخواردنەوە سوننەتە.",
      "ar": "لا يشربن أحد منكم قائماً؛ فالسنة الشرب جالساً.",
      "en": "Avoid drinking while standing; it is Sunnah to drink while sitting.",
      "source_ku": "صحيح مسلم",
      "source_ar": "صحيح مسلم",
      "source_en": "Sahih Muslim",
    },
    {
      "id": 39,
      "icon": "🏥",
      "ku": "سەردانی نەخۆش بکە؛ ئەوە مافێکی گەورەی موسڵمانانە لەسەر یەکتری.",
      "ar": "عُد المريض؛ فإنه من حق المسلم على المسلم.",
      "en": "Visit the sick; it is one of the rights of a Muslim over another.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 40,
      "icon": "👕",
      "ku": "لە کاتی لەبەرکردنی پۆشاکدا بە لای ڕاست دەست پێ بکە.",
      "ar": "كان يعجبه التيمُّن في تَنَعُّلِهِ وتَرَبُّلِهِ وطُهُورِهِ وفي شَأْنِهِ كُلِّهِ.",
      "en": "Start with the right side when putting on clothes or garments.",
      "source_ku": "سنن الترمذي",
      "source_ar": "سنن الترمذي",
      "source_en": "Sunan At-Tirmidhi",
    },
    {
      "id": 41,
      "icon": "🪞",
      "ku": "کاتێک سەیری ئاوێنە دەکەیت بڵێ: (اللَّهُمَّ كَمَا حَسَّنْتَ خَلْقِي فَحَسِّنْ خُلُقِي).",
      "ar": "قل عند النظر في المرآة: (اللهم كما حسّنتَ خَلْقي فحسِّن خُلُقي).",
      "en": "When looking in mirror, say: 'O Allah, as You made my creation beautiful, make my character beautiful'.",
      "source_ku": "مسند أحمد",
      "source_ar": "مسند أحمد",
      "source_en": "Musnad Ahmad",
    },
    {
      "id": 42,
      "icon": "⛰️",
      "ku": "کاتێک دەچیتە شوێنێکی بەرز بڵێ (اللَّهُ أَكْبَرُ)، و کاتێک دێیتە خوارەوە بڵێ (سُبْحَانَ اللَّهِ).",
      "ar": "كنا إذا صعدنا كبرنا (الله أكبر)، وإذا نزلنا سبحنا (سبحان الله).",
      "en": "Say 'Allahu Akbar' when ascending and 'SubhanAllah' when descending.",
      "source_ku": "صحيح البخاري",
      "source_ar": "صحيح البخاري",
      "source_en": "Sahih Bukhari",
    },
    {
      "id": 43,
      "icon": "🚪",
      "ku": "کاتێک دەچیتە سەرئاو (تەوالێت) بە پێی چەپ بچۆ ژوورەوە و بڵێ: (اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْخُبُثِ وَالْخَبَائِثِ).",
      "ar": "ادخل الخلاء بالرجل اليسرى وقل: (اللهم إني أعوذ بك من الخُبْث والخبائث).",
      "en": "Enter the bathroom with your left foot and seek refuge in Allah from male and female devils.",
      "source_ku": "متفق عليه",
      "source_ar": "متفق عليه",
      "source_en": "Bukhari & Muslim",
    },
    {
      "id": 44,
      "icon": "🚪",
      "ku": "کاتێک لە سەرئاو (تەوالێت) دێیتە دەرەوە بە پێی ڕاست وەرە دەرەوە و بڵێ: (غُفْرَانَكَ).",
      "ar": "اخرج من الخلاء بالرجل اليمنى وقل: (غفرانك).",
      "en": "Exit the bathroom with your right foot and say: 'Ghufranak'.",
      "source_ku": "سنن أبي داود",
      "source_ar": "سنن أبي داود",
      "source_en": "Sunan Abu Dawud",
    },
    {
      "id": 45,
      "icon": "🌿",
      "ku": "مەجلسی زیکر و دەرسە دینییەکان ئامادە بە؛ فریشتەکان باڵەکانیان بۆ دادەنێن و ڕەحمەتی ئیلاهییان تێدا دادەبەزێت.",
      "ar": "احرص على مجالس الذكر والتعلم؛ فإن المصلين والغافلين تحفهم الملائكة وتغشاهم الرحمة.",
      "en": "Attend gatherings of knowledge and remembrance; angels surround them and mercy covers them.",
      "source_ku": "صحيح مسلم",
      "source_ar": "صحيح مسلم",
      "source_en": "Sahih Muslim",
    },
  ];
}
