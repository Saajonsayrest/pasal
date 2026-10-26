import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

/// Shows a load result on a screen that scrolls. The error card gets a fixed height, because a
/// centred card has no height inside a scroll view.
Widget loadedOr<T>(AsyncValue<T> value, Widget Function(T data) data, {required VoidCallback onRetry}) {
  if (value.hasError && !value.hasValue) {
    return SizedBox(height: 420, child: ErrorView(error: value.error!, onRetry: onRetry));
  }
  if (!value.hasValue) return const SkeletonList();
  return data(value.requireValue);
}

/// Expense categories the app offers. The API keeps the key in lower case.
const expenseCategories = <({String key, String en, String ne, IconData icon})>[
  (key: 'bills', en: 'Bills', ne: 'बिल', icon: Icons.bolt_rounded),
  (key: 'rent', en: 'Rent', ne: 'भाडा', icon: Icons.home_rounded),
  (key: 'salary', en: 'Salary', ne: 'तलब', icon: Icons.payments_rounded),
  (key: 'transport', en: 'Transport', ne: 'यातायात', icon: Icons.directions_bus_rounded),
  (key: 'repair', en: 'Repair', ne: 'मर्मत', icon: Icons.build_rounded),
  (key: 'tea and snacks', en: 'Tea and snacks', ne: 'चिया र खाजा', icon: Icons.local_cafe_rounded),
  (key: 'other', en: 'Other', ne: 'अन्य', icon: Icons.more_horiz_rounded),
];

/// The stored category text in the form the lists use: trimmed, lower case, '' when none.
String categoryKey(String? category) => (category ?? '').trim().toLowerCase();

/// The name of a category. A custom category shows the text the owner typed.
String categoryName(BuildContext context, String key) {
  for (final c in expenseCategories) {
    if (c.key == key) {
      return context.tr(c.en, c.ne);
    }
  }
  return key.isEmpty ? context.tr('No category', 'वर्ग छैन') : key;
}

IconData categoryIcon(String key) {
  for (final c in expenseCategories) {
    if (c.key == key) {
      return c.icon;
    }
  }
  return Icons.more_horiz_rounded;
}

/// Payment methods the app knows. Other codes show as they are.
const paymentMethods = <({String key, String en, String ne})>[
  (key: 'cash', en: 'Cash', ne: 'नगद'),
  (key: 'qr', en: 'QR', ne: 'QR'),
  (key: 'bank', en: 'Bank', ne: 'बैंक'),
  (key: 'card', en: 'Card', ne: 'कार्ड'),
  (key: 'esewa', en: 'eSewa', ne: 'eSewa'),
  (key: 'khalti', en: 'Khalti', ne: 'Khalti'),
];

String methodName(BuildContext context, String key) {
  for (final m in paymentMethods) {
    if (m.key == key) {
      return context.tr(m.en, m.ne);
    }
  }
  return key;
}
