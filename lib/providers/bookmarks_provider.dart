import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';

class BookmarkItem {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'quran', 'hadith', 'adhkar'
  final int? surahId;
  final String? surahName;
  final int? hadithId;
  final String? adhkarId;

  BookmarkItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.surahId,
    this.surahName,
    this.hadithId,
    this.adhkarId,
  });

  factory BookmarkItem.fromJson(Map<String, dynamic> json) {
    return BookmarkItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      surahId: json['surahId'] as int?,
      surahName: json['surahName']?.toString(),
      hadithId: json['hadithId'] as int?,
      adhkarId: json['adhkarId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'surahId': surahId,
      'surahName': surahName,
      'hadithId': hadithId,
      'adhkarId': adhkarId,
    };
  }
}

class BookmarksNotifier extends StateNotifier<List<BookmarkItem>> {
  final SharedPreferences _prefs;

  BookmarksNotifier(this._prefs) : super([]) {
    _loadBookmarks();
  }

  void _loadBookmarks() {
    final raw = _prefs.getString('bookmarks');
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        state = list.map((item) => BookmarkItem.fromJson(item)).toList();
      } catch (e) {
        debugPrint('[BookmarksProvider] Error loading data: $e');
        state = [];
      }
    }
  }

  Future<void> _saveBookmarks() async {
    final raw = jsonEncode(state.map((e) => e.toJson()).toList());
    await _prefs.setString('bookmarks', raw);
  }

  Future<void> addBookmark(BookmarkItem item) async {
    if (!state.any((e) => e.id == item.id)) {
      state = [...state, item];
      await _saveBookmarks();
    }
  }

  Future<void> removeBookmark(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _saveBookmarks();
  }

  bool isBookmarked(String id) {
    return state.any((e) => e.id == id);
  }
}

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<BookmarkItem>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BookmarksNotifier(prefs);
});
