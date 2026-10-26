import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';

/// A bottom sheet for quick tasks (take payment, adjust stock, pick a customer).
/// The builder gets the sheet's own context. Close with `Navigator.pop(context, value)`.
Future<T?> showPasalSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context) builder,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) {
      final inset = MediaQuery.of(ctx).viewInsets.bottom;
      final body = Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: ctx.text.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(
                  tooltip: ctx.tr('Close', 'बन्द'),
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            builder(ctx),
          ],
        ),
      );
      return scrollable ? SingleChildScrollView(child: body) : body;
    },
  );
}

/// "Are you sure?" sheet. Returns true when the person confirms.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final ok = await showPasalSheet<bool>(
    context,
    title: title,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: ctx.text.bodyLarge),
        const SizedBox(height: 20),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: ctx.colors.bad, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.tr('Cancel', 'रद्द'))),
      ],
    ),
  );
  return ok ?? false;
}
