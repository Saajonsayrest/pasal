import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

/// Grey bars shown in a home card while its numbers load.
class CardLoading extends StatelessWidget {
  const CardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.scheme.surfaceContainerHighest;
    Widget bar(double width) => Container(
          width: width,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bar(90), const SizedBox(height: 10), bar(140)],
    );
  }
}

/// A small error line inside one home card, with a retry. The other cards are not affected.
class CardError extends StatelessWidget {
  const CardError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, color: context.colors.bad),
        const SizedBox(width: 8),
        Expanded(child: Text(context.tr('Could not load', 'लोड गर्न सकिएन'), style: context.text.bodySmall)),
        TextButton(onPressed: onRetry, child: Text(context.tr('Try again', 'फेरि प्रयास गर्नुहोस्'))),
      ],
    );
  }
}

/// A heading with an optional link. The title wraps when it is long (the shared SectionTitle does not).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.action, this.onAction, super.key});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// "due today", "due in 16 days", "3 days late".
String dueLabel(BuildContext context, int days) {
  if (days == 0) return context.tr('due today', 'आजै बुझाउने');
  if (days < 0) return context.tr('${context.num(-days)} days late', '${context.num(-days)} दिन ढिला');
  final unit = days == 1 ? 'day' : 'days';
  return context.tr('due in ${context.num(days)} $unit', '${context.num(days)} दिनमा बुझाउने');
}

/// "Mon" or "सोम" for an AD date.
String shortWeekday(BuildContext context, String ad) {
  const en = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const ne = ['आइत', 'सोम', 'मंगल', 'बुध', 'बिही', 'शुक्र', 'शनि'];
  final index = DateTime.parse('${ad}T00:00:00Z').weekday % 7;
  return context.tr(en[index], ne[index]);
}

/// One sale in a "recent sales" list. Walk-in sales have no customer name.
class RecentSaleRow extends StatelessWidget {
  const RecentSaleRow({required this.sale, super.key});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final customer = sale.customer;
    return ListRow(
      leading: customer == null ? const IconTile(Icons.person_rounded, tone: Tone.good, size: 44) : AvatarCircle(customer.name),
      title: customer?.name ?? context.tr('Walk-in customer', 'पसलमा आएका ग्राहक'),
      subtitle: '${sale.billNo ?? ''} · ${formatTime(sale.soldAt)}',
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(context.rs(sale.total), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (sale.balance > 0)
            PBadge(context.tr('Credit', 'उधारो'), tone: Tone.warn)
          else
            PBadge(context.tr('Paid', 'भुक्तानी भयो'), tone: Tone.good),
        ],
      ),
      onTap: () => context.push('/sales/${sale.id}'),
    );
  }
}
