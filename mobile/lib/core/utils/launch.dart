import 'package:flutter/widgets.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

String _cleanPhone(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

/// WhatsApp number: digits only. Numbers without a country code get Nepal's (977).
String whatsappNumber(String phone) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length <= 10) d = '977${d.replaceFirst(RegExp(r'^0+'), '')}';
  return d;
}

Uri telUri(String phone) => Uri(scheme: 'tel', path: _cleanPhone(phone));

Uri smsUri(String phone, String text) => Uri(scheme: 'sms', path: _cleanPhone(phone), queryParameters: {'body': text});

Uri whatsappUri(String phone, String text) => Uri.https('wa.me', '/${whatsappNumber(phone)}', {'text': text});

Future<void> _open(BuildContext context, Uri uri) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) showProblem(context, context.tr('Could not open this on the phone.', 'फोनमा यो खोल्न सकिएन।'));
}

Future<void> callPhone(BuildContext context, String phone) => _open(context, telUri(phone));

Future<void> sendSms(BuildContext context, String phone, String text) => _open(context, smsUri(phone, text));

Future<void> sendWhatsapp(BuildContext context, String phone, String text) => _open(context, whatsappUri(phone, text));

/// The phone's own share sheet.
Future<void> shareText(String text, {String? subject}) => SharePlus.instance.share(ShareParams(text: text, subject: subject));
