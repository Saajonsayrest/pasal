import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';

/// A short message at the bottom with a light tap of vibration:
///
///     showToast(context, 'Saved', 'सेभ भयो');
void showToast(BuildContext context, String en, [String? ne]) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  HapticFeedback.lightImpact();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2200),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF7EE2B1)),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr(en, ne))),
          ],
        ),
      ),
    );
}

/// The same bar for a problem.
void showProblem(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Color(0xFFFF8A8A)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
