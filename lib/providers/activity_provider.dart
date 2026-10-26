import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';

class BadgeItem {
  final String nameKu;
  final String nameAr;
  final String nameEn;
  final String earned;

  BadgeItem({
    required this.nameKu,
    required this.nameAr,
    required this.nameEn,
    required this.earned,
  });

  factory BadgeItem.fromJson(Map<String, dynamic> json) {
    return BadgeItem(
      nameKu: (json['name_ku'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: (json['name_en'] ?? '').toString(),
      earned: (json['earned'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name_ku': nameKu,
      'name_ar': nameAr,
      'name_en': nameEn,
      'earned': earned,
    };
  }
}

class ActivityState {
  final Map<String, int> activityLog;
  final int streak;
  final List<BadgeItem> badges;
  final Set<String> completedWorshipDays;

  ActivityState({
    required this.activityLog,
    required this.streak,
    required this.badges,
    this.completedWorshipDays = const {},
  });

  ActivityState copyWith({
    Map<String, int>? activityLog,
    int? streak,
    List<BadgeItem>? badges,
    Set<String>? completedWorshipDays,
  }) {
    return ActivityState(
      activityLog: activityLog ?? this.activityLog,
      streak: streak ?? this.streak,
      badges: badges ?? this.badges,
      completedWorshipDays: completedWorshipDays ?? this.completedWorshipDays,
    );
  }
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  final SharedPreferences _prefs;

  ActivityNotifier(this._prefs)
      : super(ActivityState(activityLog: {}, streak: 0, badges: [], completedWorshipDays: const {})) {
    _loadActivity();
  }

  static int calculateWorshipStreak(Set<String> completedDays, [DateTime? nowParam]) {
    final now = nowParam ?? DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final bool isTodayCompleted = completedDays.contains(todayKey);
    final bool isYesterdayCompleted = completedDays.contains(yesterdayKey);

    if (!isTodayCompleted && !isYesterdayCompleted) {
      return 0;
    }

    int count = 0;
    DateTime checkDate = isTodayCompleted ? now : yesterday;

    while (true) {
      final key = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (completedDays.contains(key)) {
        count++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return count;
  }

  void _loadActivity() {
    // Load log
    Map<String, int> log = {};
    final rawLog = _prefs.getString('activityLog');
    if (rawLog != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(rawLog);
        log = decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
      } catch (e) {
        debugPrint('[ActivityProvider] Error loading activityLog: $e');
      }
    }

    // Load badges
    List<BadgeItem> badgeList = [];
    final rawBadges = _prefs.getString('badges');
    if (rawBadges != null) {
      try {
        final List<dynamic> decoded = jsonDecode(rawBadges);
        badgeList = decoded
            .map((item) => BadgeItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('[ActivityProvider] Error loading badges: $e');
      }
    }

    // Load completed worship days
    Set<String> completedDays = {};
    final rawDays = _prefs.getStringList('completed_worship_days');
    if (rawDays != null) {
      completedDays = rawDays.toSet();
    }

    // Validate streak: if worship days present, calculate streak precisely
    final now = DateTime.now();
    int streak = _prefs.getInt('streak') ?? 0;
    if (completedDays.isNotEmpty) {
      streak = calculateWorshipStreak(completedDays, now);
      _prefs.setInt('streak', streak);
    } else if (streak > 0) {
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final todayCount = log[todayKey] ?? 0;
      final yesterdayCount = log[yesterdayKey] ?? 0;
      if (todayCount == 0 && yesterdayCount == 0) {
        streak = 0;
        _prefs.setInt('streak', 0);
      }
    }

    state = ActivityState(
      activityLog: log,
      streak: streak,
      badges: badgeList,
      completedWorshipDays: completedDays,
    );
  }

  Timer? _saveDebounceTimer;

  void _scheduleSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _saveActivity();
      }
    });
  }

  Future<void> _saveActivity() async {
    if (!mounted) return;
    final snapshot = state;
    await _prefs.setString('activityLog', jsonEncode(snapshot.activityLog));
    await _prefs.setInt('streak', snapshot.streak);
    await _prefs.setString('badges', jsonEncode(snapshot.badges.map((e) => e.toJson()).toList()));
    await _prefs.setStringList('completed_worship_days', snapshot.completedWorshipDays.toList());
  }

  Future<int> recordWorshipCompletion({required bool isCompleted, DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateKey = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    final updatedCompletedDays = Set<String>.from(state.completedWorshipDays);
    if (isCompleted) {
      updatedCompletedDays.add(dateKey);
    } else {
      updatedCompletedDays.remove(dateKey);
    }

    final newStreak = calculateWorshipStreak(updatedCompletedDays, DateTime.now());

    // Update activity log so it reflects worship activity
    final log = Map<String, int>.from(state.activityLog);
    if (isCompleted) {
      log[dateKey] = (log[dateKey] ?? 0) + 7;
    }

    // Award streak & worship badges
    List<BadgeItem> activeBadges = List<BadgeItem>.from(state.badges);
    if (isCompleted && !activeBadges.any((b) => b.nameEn == 'Worship Devotee')) {
      activeBadges.add(BadgeItem(
        nameKu: 'پارێزەری نوێژ و زیکر',
        nameAr: 'مواظب الصلاة والذكر',
        nameEn: 'Worship Devotee',
        earned: dateKey,
      ));
    }

    if (newStreak >= 3 && !activeBadges.any((b) => b.nameEn == '3-Day Worship Streak')) {
      activeBadges.add(BadgeItem(
        nameKu: 'بەردەوامی ٣ ڕۆژ',
        nameAr: 'مواظبة ٣ أيام',
        nameEn: '3-Day Worship Streak',
        earned: dateKey,
      ));
    }

    if (newStreak >= 7 && !activeBadges.any((b) => b.nameEn == '7-Day Worship Streak')) {
      activeBadges.add(BadgeItem(
        nameKu: 'بەردەوامی ٧ ڕۆژ',
        nameAr: 'مواظبة ٧ أيام',
        nameEn: '7-Day Worship Streak',
        earned: dateKey,
      ));
    }

    if (newStreak >= 30 && !activeBadges.any((b) => b.nameEn == '30-Day Master')) {
      activeBadges.add(BadgeItem(
        nameKu: 'پێشەوای بەردەوامی',
        nameAr: 'سيد المواظبة',
        nameEn: '30-Day Master',
        earned: dateKey,
      ));
    }

    state = state.copyWith(
      completedWorshipDays: updatedCompletedDays,
      streak: newStreak,
      activityLog: log,
      badges: activeBadges,
    );

    await _prefs.setStringList('completed_worship_days', updatedCompletedDays.toList());
    await _prefs.setInt('streak', newStreak);
    await _prefs.setString('activityLog', jsonEncode(log));
    await _prefs.setString('badges', jsonEncode(activeBadges.map((e) => e.toJson()).toList()));

    return newStreak;
  }

  Future<void> logActivity(int count) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final log = Map<String, int>.from(state.activityLog);
    
    log[today] = (log[today] ?? 0) + count;
    
    int currentStreak = state.streak;
    final int worshipStreak = calculateWorshipStreak(state.completedWorshipDays);
    if (worshipStreak > currentStreak) {
      currentStreak = worshipStreak;
    } else if (state.completedWorshipDays.isEmpty) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];
      if (log[today] == count) {
        if (log[yesterday] != null && log[yesterday]! > 0) {
          currentStreak += 1;
        } else {
          currentStreak = 1;
        }
      }
    }

    List<BadgeItem> activeBadges = List<BadgeItem>.from(state.badges);
    
    if (log[today]! >= 33 && !activeBadges.any((b) => b.nameEn == 'Dhikr Novice')) {
      activeBadges.add(BadgeItem(
        nameKu: 'ویردنووس',
        nameAr: 'ذاكر مبتدئ',
        nameEn: 'Dhikr Novice',
        earned: today,
      ));
    }

    final total = log.values.reduce((a, b) => a + b);
    if (total >= 100 && !activeBadges.any((b) => b.nameEn == 'Quran Reader')) {
      activeBadges.add(BadgeItem(
        nameKu: 'قورئان خوێن',
        nameAr: 'قارئ القرآن',
        nameEn: 'Quran Reader',
        earned: today,
      ));
    }

    final bool badgeAdded = activeBadges.length > state.badges.length;
    state = state.copyWith(activityLog: log, streak: currentStreak, badges: activeBadges);

    if (badgeAdded) {
      await _saveActivity();
    } else {
      _scheduleSave();
    }
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    final snapshot = state;
    _prefs.setString('activityLog', jsonEncode(snapshot.activityLog));
    _prefs.setInt('streak', snapshot.streak);
    _prefs.setString('badges', jsonEncode(snapshot.badges.map((e) => e.toJson()).toList()));
    _prefs.setStringList('completed_worship_days', snapshot.completedWorshipDays.toList());
    super.dispose();
  }
}

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ActivityNotifier(prefs);
});
