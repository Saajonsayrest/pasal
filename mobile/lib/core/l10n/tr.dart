import 'package:flutter/widgets.dart';
import 'package:pasal_mobile/core/utils/money.dart' as money;

/// Language switch without code generation: every screen text is written once in English and once
/// in Nepali at the place where it is used. This keeps the Nepali text next to the English text.
///
///     Text(context.tr('Add customer', 'ग्राहक थप्ने'))
///
/// [Lang] holds the current choice. [SettingsNotifier] keeps it in sync. The context extension also
/// reads the app locale, so a widget that calls `context.tr` rebuilds by itself when the language changes.
class Lang {
  Lang._();

  /// True when the app language is Nepali.
  static bool ne = false;

  /// Show the Nepali (BS) date first. When false the AD date comes first.
  static bool bsDates = true;
}

const _neDigits = '०१२३४५६७८९';

/// Nepali digits when the language is Nepali. Pass any text that holds numbers.
String digits(Object value) {
  final s = value.toString();
  if (!Lang.ne) return s;
  return s.replaceAllMapped(RegExp(r'\d'), (m) => _neDigits[int.parse(m[0]!)]);
}

extension TrContext on BuildContext {
  /// True when the app language is Nepali. Registers this widget to rebuild when the language changes.
  bool get isNe => Localizations.localeOf(this).languageCode == 'ne';

  /// English or Nepali text.
  String tr(String en, [String? ne]) => isNe && ne != null ? ne : en;

  /// Money as "Rs 1,24,000" (see [money.rs]), rebuilding on language change.
  String rs(int? paisa, {bool paisaDigits = false}) {
    isNe;
    return money.rs(paisa, paisa: paisaDigits);
  }

  /// A number with Indian grouping and Nepali digits in Nepali mode.
  String num(int value) {
    isNe;
    return money.num0(value);
  }

  /// English plural helper. Nepali has the same word for one and many.
  String plural(int n, String one, String many, [String? ne]) {
    if (isNe && ne != null) return ne;
    return n == 1 ? one : many;
  }
}
