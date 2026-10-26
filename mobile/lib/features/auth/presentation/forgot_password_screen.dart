import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/auth/data/account_repository.dart';

/// A2. Asks for the email. The answer is the same whether or not the account exists.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await guard(
      () async {
        await ref.read(accountRepositoryProvider).forgotPassword(_email.text.trim());
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = ok ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('Forgot password', 'पासवर्ड बिर्सनुभयो'),
      body: _sent ? _sentView(context) : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final canSend = !_busy && _email.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('Forgot password?', 'पासवर्ड बिर्सनुभयो?'), style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          context.tr('Enter your email. We will send a link to make a new password.', 'तपाईंको इमेल लेख्नुहोस्। हामी नयाँ पासवर्ड बनाउने लिंक पठाउँछौं।'),
          style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PField(
                label: context.tr('Email', 'इमेल'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                error: _error?.field('email'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => canSend ? _submit() : null,
              ),
              if (_error?.general != null) ...[
                const SizedBox(height: 12),
                AlertBox(_error!.message),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: _busy ? context.tr('Sending…', 'पठाउँदैछ…') : context.tr('Send reset link', 'रिसेट लिंक पठाउने'),
                icon: Icons.send_rounded,
                busy: _busy,
                onPressed: canSend ? _submit : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AlertBox(
          context.tr('Staff can also ask the shop owner to reset their password.', 'कर्मचारीले पनि पसलको मालिकलाई पासवर्ड रिसेट गर्न भन्न सक्नुहुन्छ।'),
          tone: Tone.info,
          icon: Icons.info_outline_rounded,
        ),
      ],
    );
  }

  Widget _sentView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(Icons.mark_email_read_rounded, tone: Tone.good, size: 56),
              const SizedBox(height: 14),
              Text(context.tr('Check your email', 'इमेल जाँच गर्नुहोस्'), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                context.tr('If the email has an account, a link is on its way.', 'इमेलसँग खाता भए, लिंक बाटोमा छ।'),
                style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('The link works for ${context.num(60)} minutes.', 'लिंक ${context.num(60)} मिनेटसम्म चल्छ।'),
                style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () => context.go('/login'),
          child: Text(context.tr('Back to log in', 'लग इन गर्ने')),
        ),
      ],
    );
  }
}
