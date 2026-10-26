import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A cash count the owner saved for one day. Money is whole paisa.
class CashCount {
  const CashCount({required this.day, required this.counted, required this.expected});

  /// AD day "YYYY-MM-DD".
  final String day;
  final int counted;
  final int expected;

  /// Negative when the drawer is short.
  int get diff => counted - expected;
}

/// Counts are kept on this phone only, under `pasal_cash_count_<date>` in SharedPreferences.
class CashCountStore {
  CashCountStore(this._prefs);

  static const prefix = 'pasal_cash_count_';

  final SharedPreferences _prefs;

  CashCount? read(String day) {
    final raw = _prefs.getString('$prefix$day');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CashCount(day: day, counted: (json['counted'] as num).toInt(), expected: (json['expected'] as num).toInt());
    } catch (_) {
      return null;
    }
  }

  Future<void> save(CashCount count) => _prefs.setString(
        '$prefix${count.day}',
        jsonEncode({'counted': count.counted, 'expected': count.expected}),
      );

  /// Every saved day, newest first.
  List<CashCount> all() {
    final days = _prefs.getKeys().where((k) => k.startsWith(prefix)).map((k) => k.substring(prefix.length)).toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days) ?read(day),
    ];
  }
}

final cashCountStoreProvider = Provider<CashCountStore>((ref) => CashCountStore(ref.watch(sharedPrefsProvider)));

final savedCashCountsProvider = Provider.autoDispose<List<CashCount>>((ref) => ref.watch(cashCountStoreProvider).all());
