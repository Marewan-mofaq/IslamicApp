import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';

class QazaState {
  final int fajr;
  final int dhuhr;
  final int asr;
  final int maghrib;
  final int isha;
  final int witr;

  QazaState({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.witr,
  });

  QazaState copyWith({
    int? fajr,
    int? dhuhr,
    int? asr,
    int? maghrib,
    int? isha,
    int? witr,
  }) {
    return QazaState(
      fajr: fajr ?? this.fajr,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      witr: witr ?? this.witr,
    );
  }

  Map<String, int> toMap() {
    return {
      'fajr': fajr,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
      'witr': witr,
    };
  }
}

class QazaNotifier extends StateNotifier<QazaState> {
  final SharedPreferences _prefs;

  QazaNotifier(this._prefs)
      : super(QazaState(fajr: 0, dhuhr: 0, asr: 0, maghrib: 0, isha: 0, witr: 0)) {
    _loadQaza();
  }

  void _loadQaza() {
    final raw = _prefs.getString('qazaData');
    if (raw != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(raw);
        state = QazaState(
          fajr: map['fajr'] as int? ?? 0,
          dhuhr: map['dhuhr'] as int? ?? 0,
          asr: map['asr'] as int? ?? 0,
          maghrib: map['maghrib'] as int? ?? 0,
          isha: map['isha'] as int? ?? 0,
          witr: map['witr'] as int? ?? 0,
        );
      } catch (e) {
        debugPrint('[QazaProvider] Error loading data: $e');
      }
    }
  }

  Future<void> _saveQaza() async {
    final raw = jsonEncode(state.toMap());
    await _prefs.setString('qazaData', raw);
  }

  Future<void> updateQaza(String prayerId, int delta) async {
    int val;
    switch (prayerId) {
      case 'fajr':
        val = (state.fajr + delta).clamp(0, 999999);
        state = state.copyWith(fajr: val);
        break;
      case 'dhuhr':
        val = (state.dhuhr + delta).clamp(0, 999999);
        state = state.copyWith(dhuhr: val);
        break;
      case 'asr':
        val = (state.asr + delta).clamp(0, 999999);
        state = state.copyWith(asr: val);
        break;
      case 'maghrib':
        val = (state.maghrib + delta).clamp(0, 999999);
        state = state.copyWith(maghrib: val);
        break;
      case 'isha':
        val = (state.isha + delta).clamp(0, 999999);
        state = state.copyWith(isha: val);
        break;
      case 'witr':
        val = (state.witr + delta).clamp(0, 999999);
        state = state.copyWith(witr: val);
        break;
    }
    await _saveQaza();
  }

  Future<void> setQazaData(QazaState data) async {
    state = data;
    await _saveQaza();
  }
}

final qazaProvider = StateNotifierProvider<QazaNotifier, QazaState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QazaNotifier(prefs);
});
