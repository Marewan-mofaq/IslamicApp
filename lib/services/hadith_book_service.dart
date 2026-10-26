import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data_service.dart';

class HadithBookService {
  // Book key mappings
  static const List<Map<String, dynamic>> books = [
    { 'key': 'kurdish', 'name_ar': 'أحاديث مترجمة بالكردية', 'name_ku': 'فەرموودە بە کوردی', 'name_en': 'Kurdish Curated', 'icon': Icons.auto_awesome_rounded },
    { 'key': 'bukhari', 'name_ar': 'صحيح البخاري', 'name_ku': 'سەحیحی بوخاری', 'name_en': 'Sahih al-Bukhari', 'icon': Icons.menu_book_rounded },
    { 'key': 'muslim', 'name_ar': 'صحيح مسلم', 'name_ku': 'سەحیحی موسلیم', 'name_en': 'Sahih Muslim', 'icon': Icons.library_books_rounded },
    { 'key': 'abudawud', 'name_ar': 'سنن أبي داود', 'name_ku': 'سونەنی ئەبوو داود', 'name_en': 'Sunan Abu Dawud', 'icon': Icons.book_rounded },
    { 'key': 'tirmidhi', 'name_ar': 'جامع الترمذي', 'name_ku': 'جامیعی تیرمیزی', 'name_en': 'Jami at-Tirmidhi', 'icon': Icons.collections_bookmark_rounded },
    { 'key': 'nasai', 'name_ar': 'سنن النسائي', 'name_ku': 'سونەنی نەسائی', 'name_en': "Sunan an-Nasa'i", 'icon': Icons.import_contacts_rounded },
    { 'key': 'ibnmajah', 'name_ar': 'سنن ابن ماجه', 'name_ku': 'سونەنی ئیبن ماجە', 'name_en': 'Sunan Ibn Majah', 'icon': Icons.chrome_reader_mode_rounded },
    { 'key': 'nawawi40', 'name_ar': 'الأربعون النووية', 'name_ku': 'چلی نەوەوی', 'name_en': "Nawawi's Forty Hadith", 'icon': Icons.star_rounded },
  ];

  static final Map<String, dynamic> _bookCache = {};
  static final Map<String, Future<Map<String, dynamic>?>> _inFlightLoads = {};

  // Load a book by key (lazy & cached)
  static Future<Map<String, dynamic>?> loadBook(String bookKey) async {
    if (_bookCache.containsKey(bookKey)) {
      return _bookCache[bookKey];
    }

    if (_inFlightLoads.containsKey(bookKey)) {
      return _inFlightLoads[bookKey];
    }

    final loadFuture = () async {
      try {
        if (bookKey == 'kurdish') {
          final bookData = await _getKurdishBook();
          _bookCache[bookKey] = bookData;
          return bookData;
        }

        final raw = await rootBundle.loadString('assets/data/hadith-books/$bookKey.json');
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _bookCache[bookKey] = data;
        return data;
      } catch (e) {
        debugPrint('Error loading hadith book $bookKey: $e');
        return null;
      } finally {
        _inFlightLoads.remove(bookKey);
      }
    }();

    _inFlightLoads[bookKey] = loadFuture;
    return loadFuture;
  }

  // Curate unified Kurdish book from hadith.json
  static Future<Map<String, dynamic>> _getKurdishBook() async {
    final rawHadiths = await DataService.loadHadiths();
    final rawCollections = await DataService.loadHadithCollections();

    final List<Map<String, dynamic>> chapters = [];
    for (int i = 0; i < rawCollections.length; i++) {
      chapters.add({
        'id': i + 1,
        'arabic': rawCollections[i].nameAr,
        'english': rawCollections[i].nameEn,
        'collectionId': rawCollections[i].id,
      });
    }

    final List<Map<String, dynamic>> hadiths = [];
    final Set<String> seenArabic = {};

    for (final h in rawHadiths) {
      final cleanAr = h.arabic.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (cleanAr.isNotEmpty && seenArabic.contains(cleanAr)) continue;
      if (cleanAr.isNotEmpty) seenArabic.add(cleanAr);

      final chIndex = chapters.indexWhere((c) => c['collectionId'] == h.collection);
      hadiths.add({
        'id': h.id,
        'idInBook': h.number,
        'chapterId': chIndex >= 0 ? chapters[chIndex]['id'] : 1,
        'arabic': h.arabic,
        'english': {
          'narrator': h.narratorEn,
          'text': h.translationEn,
        },
        'kurdish': {
          'narrator': h.narratorKu,
          'text': h.translationKu,
        },
        'narrator_ar': h.narratorAr,
        'collection': h.collection,
      });
    }

    return {
      'id': 'kurdish',
      'metadata': {
        'name_ar': 'أحاديث مترجمة بالكردية',
        'name_ku': 'فەرموودە بە کوردی',
        'name_en': 'Kurdish Translated Hadiths',
        'totalHadiths': hadiths.length,
        'totalChapters': chapters.length,
      },
      'chapters': chapters,
      'hadiths': hadiths,
    };
  }

  // Get all chapters for a book
  static Future<List<dynamic>> getChapters(String bookKey) async {
    final book = await loadBook(bookKey);
    return book?['chapters'] ?? [];
  }

  // Get hadiths in a specific chapter
  static Future<List<dynamic>> getHadithsByChapter(String bookKey, int chapterId) async {
    final book = await loadBook(bookKey);
    if (book == null) return [];
    final List<dynamic> all = book['hadiths'] ?? [];
    return all.where((h) => h['chapterId'] == chapterId).toList();
  }

  // Get hadiths paginated
  static Future<Map<String, dynamic>> getHadithsPaginated(String bookKey, {int page = 1, int pageSize = 30}) async {
    final book = await loadBook(bookKey);
    if (book == null) {
      return {
        'hadiths': [],
        'totalPages': 0,
        'currentPage': page,
        'totalHadiths': 0,
      };
    }

    final safePage = math.max(1, page);
    final List<dynamic> all = book['hadiths'] ?? [];
    final total = all.length;
    final totalPages = (total / pageSize).ceil();
    final start = (safePage - 1) * pageSize;
    final end = math.min(start + pageSize, total);

    if (start >= total) {
      return {
        'hadiths': [],
        'totalPages': totalPages,
        'currentPage': page,
        'totalHadiths': total,
      };
    }

    return {
      'hadiths': all.sublist(start, end),
      'totalPages': totalPages,
      'currentPage': page,
      'totalHadiths': total,
    };
  }

  // Search in a book
  static Future<List<dynamic>> searchHadiths(String bookKey, String query, {int limit = 50}) async {
    final book = await loadBook(bookKey);
    if (book == null || query.trim().isEmpty) return [];

    final q = query.toLowerCase().trim();
    final List<dynamic> all = book['hadiths'] ?? [];
    final List<dynamic> results = [];

    for (final h in all) {
      if (results.length >= limit) break;

      final arabic = h['arabic']?.toString() ?? '';
      final engText = h['english']?['text']?.toString() ?? '';
      final engNarrator = h['english']?['narrator']?.toString() ?? '';
      final kurdText = h['kurdish']?['text']?.toString() ?? '';

      final matchAr = arabic.toLowerCase().contains(q);
      final matchEn = engText.toLowerCase().contains(q) || engNarrator.toLowerCase().contains(q);
      final matchKu = kurdText.toLowerCase().contains(q);

      if (matchAr || matchEn || matchKu) {
        results.add(h);
      }
    }

    return results;
  }

  // Get Hadith of the Day (Deterministic from curated Kurdish book)
  static Future<Map<String, dynamic>?> getHadithOfTheDay({int dayOffset = 0}) async {
    final book = await loadBook('kurdish');
    if (book == null) return null;

    final List<dynamic> pool = book['hadiths'] ?? [];
    if (pool.isEmpty) return null;

    final now = DateTime.now();
    // Unique deterministic index advancing every single calendar day
    final daysSinceEpoch = DateTime(now.year, now.month, now.day).difference(DateTime(2024, 1, 1)).inDays;
    final rawIndex = (daysSinceEpoch + dayOffset) % pool.length;
    final index = rawIndex < 0 ? (rawIndex + pool.length) : rawIndex;

    final hadith = pool[index];
    final bookInfo = books.firstWhere((b) => b['key'] == 'kurdish', orElse: () => books.first);

    return {
      'hadith': hadith,
      'bookKey': 'kurdish',
      'bookInfo': bookInfo,
    };
  }

  static Future<Map<String, dynamic>?> getRandomHadith() async {
    final book = await loadBook('kurdish');
    if (book == null) return null;

    final List<dynamic> pool = book['hadiths'] ?? [];
    if (pool.isEmpty) return null;

    final index = math.Random().nextInt(pool.length);
    return pool[index] as Map<String, dynamic>;
  }
}
