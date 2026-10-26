import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/launch.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/selling/data/selling_repository.dart';
import 'package:pasal_mobile/features/selling/presentation/selling_widgets.dart';

/// The bill of one sale (/sales/:id/bill). Share as text, or WhatsApp when the customer has a phone.
/// PDF and printing are not on the phone yet.
class BillScreen extends ConsumerWidget {
  const BillScreen({required this.saleId, super.key});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(saleProvider(saleId));
    final business = ref.watch(sessionProvider).business;
    return PageScaffold(
      title: context.tr('Bill', 'बिल'),
      body: AsyncBody<Sale>(
        value: sale,
        onRetry: () => ref.invalidate(saleProvider(saleId)),
        data: (s) => _BillBody(
          sale: s,
          shopName: business?.name ?? 'PASAL',
          business: business,
          // Set on Settings, Shop details. Empty means the default thank you line.
          footer: ref.read(sharedPrefsProvider).getString('pasal_bill_footer'),
        ),
      ),
    );
  }
}

class _BillBody extends StatelessWidget {
  const _BillBody({required this.sale, required this.shopName, required this.business, this.footer});

  final Sale sale;
  final String shopName;
  final Business? business;
  final String? footer;

  String _footer(BuildContext context) {
    final saved = footer?.trim();
    return (saved == null || saved.isEmpty) ? context.tr('Thank you. Visit again.', 'धन्यवाद। फेरि आउनुहोस्।') : saved;
  }

  String _shareText(BuildContext context) {
    final bill = sale.billNo ?? '#${sale.id}';
    return [
      shopName,
      '${context.tr('Bill', 'बिल')} $bill · ${formatDate(sale.soldAt)}',
      '${context.tr('Total', 'जम्मा')}: ${context.rs(sale.total)}',
      '${context.tr('Paid', 'तिरेको')}: ${context.rs(sale.paid)}',
      if (sale.balance > 0) '${context.tr('Balance', 'बाँकी')}: ${context.rs(sale.balance)}',
      _footer(context),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final text = _shareText(context);
    final phone = sale.customer?.phone;
    final shopPhone = business?.phone;
    final shopAddress = business?.address;
    final shopPan = business?.pan;
    final customerPan = sale.customer?.pan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  AvatarCircle(shopName, size: 54),
                  const SizedBox(height: 8),
                  Text(
                    shopName,
                    textAlign: TextAlign.center,
                    style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (shopAddress != null) _centerMuted(context, shopAddress),
                  if (shopPhone != null) _centerMuted(context, '${context.tr('Phone', 'फोन')} $shopPhone'),
                  if (shopPan != null)
                    Text(
                      '${context.tr('PAN', 'PAN नं.')} $shopPan',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const Divider(height: 32),
              Text(
                context.tr('VAT bill', 'भ्याट बिल'),
                textAlign: TextAlign.center,
                style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _pair(context, context.tr('Bill no.', 'बिल नं.'), sale.billNo ?? '#${sale.id}'),
              _pair(
                context,
                context.tr('Date', 'मिति'),
                '${formatDate(sale.soldAt)}  ${formatDateSub(sale.soldAt)}',
              ),
              _pair(context, context.tr('Time', 'समय'), formatTime(sale.soldAt)),
              _pair(context, context.tr('Customer', 'ग्राहक'), sale.customer?.name ?? context.tr('Walk-in customer', 'पसलमा आएका ग्राहक')),
              if (customerPan != null) _pair(context, context.tr('Customer PAN', 'ग्राहकको PAN'), customerPan),
              const Divider(height: 28),
              for (final line in sale.items ?? const <SaleLine>[])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(line.itemName, style: context.text.bodyMedium)),
                      SizedBox(
                        width: 44,
                        child: Text(context.num(line.quantity), textAlign: TextAlign.end, style: context.text.bodyMedium),
                      ),
                      SizedBox(
                        width: 96,
                        child: Text(context.rs(line.lineTotal), textAlign: TextAlign.end, style: context.text.bodyMedium),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 28),
              MoneyRows([
                MoneyRow(context.tr('Subtotal', 'उप-जम्मा'), context.rs(sale.subtotal)),
                MoneyRow(context.tr('Discount', 'छुट'), context.rs(sale.discount)),
                MoneyRow(context.tr('Taxable amount', 'करयोग्य रकम'), context.rs(sale.taxableAmount, paisaDigits: true)),
                MoneyRow(
                  '${context.tr('VAT', 'भ्याट')} ${digits(_rate(sale.vatRate))}%',
                  context.rs(sale.vatAmount, paisaDigits: true),
                ),
                if (sale.exemptAmount > 0) MoneyRow(context.tr('No VAT items', 'भ्याट नलाग्ने सामान'), context.rs(sale.exemptAmount)),
                MoneyRow(context.tr('Total', 'जम्मा'), context.rs(sale.total), bold: true),
                if (sale.returnedTotal > 0) MoneyRow(context.tr('Returned', 'फिर्ता'), context.rs(sale.returnedTotal)),
                MoneyRow(context.tr('Paid', 'तिरेको'), context.rs(sale.paid)),
                MoneyRow(context.tr('Balance', 'बाँकी'), context.rs(sale.balance), tone: sale.balance > 0 ? Tone.warn : null),
              ]),
              const Divider(height: 28),
              Text(
                _footer(context),
                textAlign: TextAlign.center,
                style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (sale.isCancelled) ...[
          const SizedBox(height: 12),
          AlertBox(context.tr('This bill is cancelled.', 'यो बिल रद्द भएको छ।'), icon: Icons.cancel_rounded),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => shareText(text),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(context.tr('Share', 'शेयर')),
              ),
            ),
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => sendWhatsapp(context, phone, text),
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(context.tr('WhatsApp', 'व्हाट्सएप')),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.go('/sell'),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: Text(context.tr('New sale', 'नयाँ बिक्री')),
        ),
        const SizedBox(height: 14),
        Text(
          context.tr('PDF and printing are not on the phone yet. They come later.', 'PDF र प्रिन्ट अहिले फोनमा छैन। पछि आउनेछ।'),
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _centerMuted(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
      );

  Widget _pair(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label, style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant)),
            ),
            Flexible(
              child: Text(value, textAlign: TextAlign.end, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

String _rate(double rate) => rate % 1 == 0 ? rate.toInt().toString() : rate.toString();
