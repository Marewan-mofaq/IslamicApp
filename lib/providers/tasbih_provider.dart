import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';

class TasbihState {
  final int count;
  final int target;
  final String text;
  final int totalAllTime;

  TasbihState({
    required this.count,
    required this.target,
    required this.text,
    required this.totalAllTime,
  });

  TasbihState copyWith({
    int? count,
    int? target,
    String? text,
    int? totalAllTime,
  }) {
    return TasbihState(
      count: count ?? this.count,
      target: target ?? this.target,
      text: text ?? this.text,
      totalAllTime: totalAllTime ?? this.totalAllTime,
    );
  }
}

class TasbihNotifier extends StateNotifier<TasbihState> {
  final SharedPreferences _prefs;

  TasbihNotifier(this._prefs)
      : super(TasbihState(
          count: 0,
          target: 33,
          text: 'سُبْحَانَ اللَّهِ',
          totalAllTime: 0,
        )) {
    _loadTasbih();
  }

  void _loadTasbih() {
    try {
      state = TasbihState(
        count: _prefs.getInt('tasbihCount') ?? 0,
        target: _prefs.getInt('tasbihTarget') ?? 33,
        text: _prefs.getString('tasbihText') ?? 'سُبْحَانَ اللَّهِ',
        totalAllTime: _prefs.getInt('tasbihTotalAllTime') ?? 0,
      );
    } catch (e) {
      debugPrint('[TasbihProvider] Error loading data: $e');
    }
  }

  Future<void> increment() async {
    final newCount = state.count + 1;
    final newTotal = state.totalAllTime + 1;
    state = state.copyWith(count: newCount, totalAllTime: newTotal);
    await _prefs.setInt('tasbihCount', newCount);
    await _prefs.setInt('tasbihTotalAllTime', newTotal);
  }

  Future<void> reset() async {
    state = state.copyWith(count: 0);
    await _prefs.setInt('tasbihCount', 0);
  }

  Future<void> setTarget(int target) async {
    state = state.copyWith(target: target);
    await _prefs.setInt('tasbihTarget', target);
  }

  Future<void> setText(String text) async {
    state = state.copyWith(text: text);
    await _prefs.setString('tasbihText', text);
  }
}

final tasbihProvider = StateNotifierProvider<TasbihNotifier, TasbihState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TasbihNotifier(prefs);
});
