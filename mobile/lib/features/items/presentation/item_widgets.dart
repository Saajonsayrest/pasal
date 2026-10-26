import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

/// A square item photo, or a box icon when the item has no photo or it cannot load.
class ItemThumb extends StatelessWidget {
  const ItemThumb({required this.photoUrl, super.key, this.size = 44});

  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = IconTile(Icons.inventory_2_rounded, size: size);
    final url = photoUrl;
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// One item in the grid view. Low stock items get the warning colour.
class ItemGridTile extends StatelessWidget {
  const ItemGridTile({required this.item, required this.onTap, super.key});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PCard(
      onTap: onTap,
      tone: item.isLowStock ? Tone.warn : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ItemThumb(photoUrl: item.photoUrl, size: 56),
          const SizedBox(height: 10),
          Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${context.num(item.quantity)} ${item.unit}', style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
          Text(context.rs(item.sellPrice), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// A small label above a form box (the same style as the text fields).
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(text, style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
    );
  }
}

/// A name on the left and a value on the right, for the price box.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({required this.label, required this.value, super.key, this.tone});

  final String label;
  final String value;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == null || tone == Tone.neutral ? context.scheme.onSurface : toneColors(context, tone!).fg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant))),
          const SizedBox(width: 12),
          Text(value, textAlign: TextAlign.end, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// The name of the category with [id], or an empty text when there is none.
String categoryNameOf(List<Category> categories, int? id) {
  if (id == null) return '';
  for (final c in categories) {
    if (c.id == id) return c.name;
  }
  return '';
}

/// The reason of a stock change, in the chosen language.
String movementReason(BuildContext context, String reason) => switch (reason) {
      'sale' => context.tr('Sale', 'बिक्री'),
      'sale_return' => context.tr('Sale return', 'बिक्री फिर्ता'),
      'sale_cancel' => context.tr('Sale cancelled', 'बिक्री रद्द'),
      'purchase' => context.tr('Purchase', 'खरिद'),
      'adjust' => context.tr('Adjustment', 'समायोजन'),
      'count' => context.tr('Stock count', 'स्टक गणना'),
      _ => reason,
    };

/// Shown when the item id in the address is not a number.
class MissingItemScreen extends StatelessWidget {
  const MissingItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('Item details', 'सामान विवरण'),
      scroll: false,
      body: EmptyState(icon: Icons.search_off_rounded, title: context.tr('This item was not found', 'यो सामान भेटिएन')),
    );
  }
}
