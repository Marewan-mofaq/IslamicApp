import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';

class KhatamProgress {
  final int pagesRead;
  final int targetPages;
  final String startDate;

  KhatamProgress({
    required this.pagesRead,
    required this.targetPages,
    required this.startDate,
  });

  KhatamProgress copyWith({
    int? pagesRead,
    int? targetPages,
    String? startDate,
  }) {
    return KhatamProgress(
      pagesRead: pagesRead ?? this.pagesRead,
      targetPages: targetPages ?? this.targetPages,
      startDate: startDate ?? this.startDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pagesRead': pagesRead,
      'targetPages': targetPages,
      'startDate': startDate,
    };
  }
}

class KhatamNotifier extends StateNotifier<KhatamProgress> {
  final SharedPreferences _prefs;

  KhatamNotifier(this._prefs)
      : super(KhatamProgress(
          pagesRead: 0,
          targetPages: 604,
          startDate: DateTime.now().toIso8601String(),
        )) {
    _loadKhatam();
  }

  void _loadKhatam() {
    final raw = _prefs.getString('khatamProgress');
    if (raw != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(raw);
        state = KhatamProgress(
          pagesRead: map['pagesRead'] as int? ?? 0,
          targetPages: map['targetPages'] as int? ?? 604,
          startDate: map['startDate'] as String? ?? DateTime.now().toIso8601String(),
        );
      } catch (e) {
        debugPrint('[KhatamProvider] Error loading data: $e');
      }
    }
  }

  Future<void> _saveKhatam() async {
    final raw = jsonEncode(state.toMap());
    await _prefs.setString('khatamProgress', raw);
  }

  Future<void> updateProgress({int? pagesRead, int? targetPages, String? startDate}) async {
    state = state.copyWith(
      pagesRead: pagesRead,
      targetPages: targetPages,
      startDate: startDate,
    );
    await _saveKhatam();
  }
}

final khatamProvider = StateNotifierProvider<KhatamNotifier, KhatamProgress>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return KhatamNotifier(prefs);
});
