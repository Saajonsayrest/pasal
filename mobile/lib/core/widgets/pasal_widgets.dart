import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/icon_names.dart';

/// Meaning of a colour. The screens always add words or an arrow, never colour alone.
enum Tone { neutral, primary, good, warn, bad, info }

({Color fg, Color bg}) toneColors(BuildContext context, Tone tone) {
  final c = context.colors;
  final s = context.scheme;
  return switch (tone) {
    Tone.neutral => (fg: s.onSurfaceVariant, bg: s.surfaceContainerHighest),
    Tone.primary => (fg: s.onPrimaryContainer, bg: s.primaryContainer),
    Tone.good => (fg: c.good, bg: c.goodSoft),
    Tone.warn => (fg: c.warn, bg: c.warnSoft),
    Tone.bad => (fg: c.bad, bg: c.badSoft),
    Tone.info => (fg: c.info, bg: c.infoSoft),
  };
}

/// Big rounded card (about 24 px corners), the base block of every screen.
class PCard extends StatelessWidget {
  const PCard({required this.child, super.key, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.tone});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (tone == null ? context.scheme.surfaceContainerLow : toneColors(context, tone!).bg);
    final border = context.scheme.outlineVariant.withValues(alpha: 0.5);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// A big number with a small grey label above and an optional line below (Cashew style).
class StatBlock extends StatelessWidget {
  const StatBlock({required this.label, required this.value, super.key, this.sub, this.tone, this.large = false});

  final String label;
  final String value;
  final String? sub;
  final Tone? tone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = tone == null || tone == Tone.neutral ? context.scheme.onSurface : toneColors(context, tone!).fg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: (large ? context.text.displaySmall : context.text.headlineSmall)?.copyWith(fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
          ),
        ),
        if (sub != null) Text(sub!, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
      ],
    );
  }
}

/// The big tinted card on top of a screen (to collect, we owe, profit).
class HeroCard extends StatelessWidget {
  const HeroCard({required this.child, super.key, this.tone = Tone.primary});

  final Widget child;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(Radii.xl)),
      child: child,
    );
  }
}

class PBadge extends StatelessWidget {
  const PBadge(this.text, {super.key, this.tone = Tone.neutral});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: context.text.labelSmall?.copyWith(color: c.fg, fontWeight: FontWeight.w700)),
    );
  }
}

/// Round avatar with initials.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle(this.name, {super.key, this.tone = Tone.primary, this.size = 44});

  final String name;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
      child: Text(initials(name), style: TextStyle(color: c.fg, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

/// "Hari Thapa" to "HT".
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
}

/// Square icon on a tinted tile, for rows without an avatar.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = Tone.primary, this.size = 44});

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: Icon(icon, color: c.fg, size: size * 0.5),
    );
  }
}

/// One list row: leading, title, subtitle, and an amount with a small line on the right.
class ListRow extends StatelessWidget {
  const ListRow({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.amount,
    this.amountTone,
    this.amountLabel,
    this.onTap,
    this.chevron = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Replaces the amount column when set.
  final Widget? trailing;
  final String? amount;
  final Tone? amountTone;
  final String? amountLabel;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final amountColor = amountTone == null || amountTone == Tone.neutral ? context.scheme.onSurface : toneColors(context, amountTone!).fg;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (amount != null) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount!, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: amountColor)),
                  if (amountLabel != null) Text(amountLabel!, style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                ],
              ),
            ],
            if (onTap != null && chevron) Icon(Icons.chevron_right_rounded, color: context.scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A group of rows inside one rounded card with thin lines between them.
class ListCard extends StatelessWidget {
  const ListCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: context.scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(indent: 16, endIndent: 16, height: 1, color: context.scheme.outlineVariant.withValues(alpha: 0.4)),
          ],
        ],
      ),
    );
  }
}

/// Small heading above a block, with an optional link on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// A friendly empty screen with one clear button.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, super.key, this.text, this.icon = Icons.inbox_rounded, this.actionLabel, this.onAction});

  final String title;
  final String? text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: context.scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: context.scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(text!, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grey placeholder rows while data loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final color = context.scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    Widget box(double w, double h, {bool round = false}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(round ? 99 : 8)),
        );
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                box(44, 44, round: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [box(150, 14), const SizedBox(height: 8), box(90, 12)],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Shown when a screen could not load. Offers a retry.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException ? (error as ApiException).message : context.tr('Something went wrong.', 'केही गडबड भयो।');
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: message,
      actionLabel: onRetry == null ? null : context.tr('Try again', 'फेरि प्रयास गर्नुहोस्'),
      onAction: onRetry,
    );
  }
}

/// A red box with a general message (not tied to one field).
class AlertBox extends StatelessWidget {
  const AlertBox(this.message, {super.key, this.tone = Tone.bad, this.icon = Icons.error_outline_rounded});

  final String message;
  final Tone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.fg, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: context.text.bodyMedium?.copyWith(color: c.fg, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// Material Symbols name (as the API stores for a category) to a Flutter icon.
IconData iconFromName(String? name) => symbolIcon(name);
