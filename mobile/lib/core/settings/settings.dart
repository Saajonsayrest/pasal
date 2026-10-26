import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/providers.dart';

enum ThemeChoice { light, dark, black }

/// The main colours the owner can pick (same seven as the website).
const seedColors = <Color>[
  Color(0xFF1F8A63),
  Color(0xFF2563EB),
  Color(0xFF7C4DDB),
  Color(0xFFDC2F55),
  Color(0xFFE0731A),
  Color(0xFF0E8F9E),
  Color(0xFF4B5563),
];

class AppSettings {
  const AppSettings({this.ne = false, this.theme = ThemeChoice.light, this.seed = 0xFF1F8A63, this.bsDates = true});

  /// Nepali language.
  final bool ne;
  final ThemeChoice theme;

  /// ARGB value of the main colour.
  final int seed;

  /// Show the Nepali (BS) date first.
  final bool bsDates;

  Locale get locale => Locale(ne ? 'ne' : 'en');
  Color get seedColor => Color(seed);

  AppSettings copyWith({bool? ne, ThemeChoice? theme, int? seed, bool? bsDates}) =>
      AppSettings(ne: ne ?? this.ne, theme: theme ?? this.theme, seed: seed ?? this.seed, bsDates: bsDates ?? this.bsDates);
}

/// Language, theme, main colour and date style, saved on this phone (SharedPreferences, not secrets).
class SettingsNotifier extends Notifier<AppSettings> {
  static const _kNe = 'pasal_ne';
  static const _kTheme = 'pasal_theme';
  static const _kSeed = 'pasal_seed';
  static const _kBs = 'pasal_bs_dates';

  @override
  AppSettings build() {
    final p = ref.read(sharedPrefsProvider);
    final s = AppSettings(
      ne: p.getBool(_kNe) ?? false,
      theme: ThemeChoice.values.firstWhere((t) => t.name == p.getString(_kTheme), orElse: () => ThemeChoice.light),
      seed: p.getInt(_kSeed) ?? 0xFF1F8A63,
      bsDates: p.getBool(_kBs) ?? true,
    );
    _sync(s);
    return s;
  }

  void _sync(AppSettings s) {
    Lang.ne = s.ne;
    Lang.bsDates = s.bsDates;
  }

  Future<void> _set(AppSettings s) async {
    _sync(s);
    state = s;
    final p = ref.read(sharedPrefsProvider);
    await p.setBool(_kNe, s.ne);
    await p.setString(_kTheme, s.theme.name);
    await p.setInt(_kSeed, s.seed);
    await p.setBool(_kBs, s.bsDates);
  }

  Future<void> setNepali(bool value) => _set(state.copyWith(ne: value));
  Future<void> setTheme(ThemeChoice value) => _set(state.copyWith(theme: value));
  Future<void> setSeed(Color value) => _set(state.copyWith(seed: value.toARGB32()));
  Future<void> setBsDates(bool value) => _set(state.copyWith(bsDates: value));
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
