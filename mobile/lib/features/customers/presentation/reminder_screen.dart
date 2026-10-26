import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/settings/settings.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/launch.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/customers/data/customer_repository.dart';
import 'package:pasal_mobile/features/customers/data/reminder_log.dart';

/// Reminder (website E5). A payment reminder sent by WhatsApp or SMS, or copied. The "sent" tick is kept on this phone.
class ReminderScreen extends ConsumerWidget {
  const ReminderScreen({required this.customerId, super.key});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerProvider(customerId));
    return PageScaffold(
      title: context.tr('Reminder', 'सम्झना सन्देश'),
      body: AsyncBody(
        value: async,
        onRetry: () => ref.invalidate(customerProvider(customerId)),
        data: (c) => _ReminderBody(customer: c),
      ),
    );
  }
}

class _ReminderBody extends ConsumerStatefulWidget {
  const _ReminderBody({required this.customer});

  final Customer customer;

  @override
  ConsumerState<_ReminderBody> createState() => _ReminderBodyState();
}

class _ReminderBodyState extends ConsumerState<_ReminderBody> {
  late final TextEditingController _en;
  late final TextEditingController _ne;
  late bool _nepali;
  SentReminder? _sent;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    final owes = c.owes ?? 0;
    final shop = ref.read(sessionProvider).business?.name ?? 'PASAL';
    _en = TextEditingController(text: _englishMessage(c.name, shop, owes));
    _ne = TextEditingController(text: _nepaliMessage(c.name, shop, owes));
    _nepali = ref.read(settingsProvider).ne;
    _sent = ref.read(reminderLogProvider).sentFor(c.id);
  }

  @override
  void dispose() {
    _en.dispose();
    _ne.dispose();
    super.dispose();
  }

  static String _englishMessage(String name, String shop, int owes) =>
      'Namaste $name ji. This is a reminder from $shop. Your balance is ${rs(owes)}. Please pay when you can.';

  static String _nepaliMessage(String name, String shop, int owes) {
    final amount = _toNepaliDigits(rs(owes).replaceFirst('Rs ', 'रु '));
    return 'नमस्ते $name जी। $shop बाट एउटा सम्झना। तपाईंको $amount बाँकी छ। मिलेमा तिर्नुहोला।';
  }

  TextEditingController get _text => _nepali ? _ne : _en;

  String get _phone => widget.customer.phone?.trim() ?? '';

  Future<void> _send(String channel) async {
    final text = _text.text;
    if (channel == 'whatsapp') {
      await sendWhatsapp(context, _phone, text);
    } else {
      await sendSms(context, _phone, text);
    }
    if (!mounted) return;
    final sent = await ref.read(reminderLogProvider).markSent(widget.customer.id, channel, DateTime.now());
    if (!mounted) return;
    setState(() => _sent = sent);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (!mounted) return;
    showToast(context, 'Message copied', 'सन्देश कपी भयो');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final owes = c.owes ?? 0;
    final canSend = _phone.isNotEmpty && owes > 0;
    final sent = _sent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          child: Row(
            children: [
              AvatarCircle(c.name, tone: Tone.warn, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      _phone.isEmpty ? context.tr('No phone saved', 'फोन छैन') : _phone,
                      style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(context.rs(owes), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: context.colors.warn)),
                  Text(
                    context.tr('To collect', 'उठाउन बाँकी'),
                    style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (owes <= 0)
          AlertBox(
            context.tr('Nothing is owed now, so no reminder is needed.', 'अहिले बाँकी छैन, सम्झना चाहिँदैन।'),
            tone: Tone.info,
            icon: Icons.info_rounded,
          )
        else if (_phone.isEmpty)
          AlertBox(
            context.tr('Add a phone number to send by WhatsApp or SMS.', 'व्हाट्सएप वा एसएमएस पठाउन फोन नम्बर थप्नुहोस्।'),
            tone: Tone.warn,
            icon: Icons.phone_disabled_rounded,
          ),
        if (_phone.isEmpty && owes > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push('/customers/${c.id}/edit'),
              child: Text(context.tr('Edit customer', 'ग्राहक सच्याउने')),
            ),
          ),
        if (sent != null) ...[
          const SizedBox(height: 12),
          AlertBox(
            '${sent.channel == 'sms' ? 'SMS' : 'WhatsApp'}: '
            '${context.tr('Marked as sent on ${formatDate(sent.at)}, ${formatTime(sent.at)}', '${formatDate(sent.at)}, ${formatTime(sent.at)} मा पठाएको चिनो')}',
            tone: Tone.good,
            icon: Icons.done_all_rounded,
          ),
        ],
        const SizedBox(height: 16),
        Seg<bool>(
          value: _nepali,
          onChanged: (v) => setState(() => _nepali = v),
          options: const {false: 'English', true: 'नेपाली'},
        ),
        const SizedBox(height: 12),
        PField(
          label: context.tr('Edit message', 'सन्देश सम्पादन गर्नुहोस्'),
          controller: _text,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: context.colors.good),
                onPressed: canSend ? () => _send('whatsapp') : null,
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canSend ? () => _send('sms') : null,
                icon: const Icon(Icons.sms_rounded),
                label: const Text('SMS'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _copy,
                icon: const Icon(Icons.content_copy_rounded),
                label: Text(context.tr('Copy', 'कपी')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _toNepaliDigits(String text) {
  const ne = '०१२३४५६७८९';
  return text.replaceAllMapped(RegExp(r'\d'), (m) => ne[int.parse(m[0]!)]);
}
