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
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/auth/data/account_repository.dart';

/// A2b. Sets a new password from the link in the reset email. The route reads `token` and `email`
/// from the link (`pasal://reset-password?token=...&email=...`).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.email, required this.token, super.key});

  final String email;
  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _busy = false;
  bool _tokenBad = false;
  ApiException? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _linkBad => widget.email.isEmpty || widget.token.isEmpty || _tokenBad;
  bool get _lengthBad => _password.text.isNotEmpty && (_password.text.length < 10 || _password.text.length > 100);
  bool get _mismatch => _confirm.text.isNotEmpty && _confirm.text != _password.text;
  bool get _canSave => !_busy && _password.text.isNotEmpty && _confirm.text.isNotEmpty;

  Future<void> _save() async {
    if (_lengthBad || _mismatch) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await guard(
      () async {
        await ref.read(accountRepositoryProvider).resetPassword(email: widget.email, token: widget.token, password: _password.text);
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    if (ok ?? false) {
      showToast(context, 'Password changed. Log in with the new one.', 'पासवर्ड बदलियो। नयाँ पासवर्डले लग इन गर्नुहोस्।');
      context.go('/login');
      return;
    }
    setState(() {
      _busy = false;
      _tokenBad = _error?.field('token') != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('New password', 'नयाँ पासवर्ड'),
      bottom: _linkBad
          ? null
          : PrimaryButton(
              label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save new password', 'नयाँ पासवर्ड सेभ गर्ने'),
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: _canSave ? _save : null,
            ),
      body: _linkBad ? _badLink(context) : _form(context),
    );
  }

  Widget _badLink(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlertBox(context.tr('This link is wrong or expired', 'यो लिंक गलत वा म्याद सकिएको छ')),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => context.go('/forgot-password'),
          child: Text(context.tr('Ask for a new link', 'नयाँ लिंक माग्ने')),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final lengthError = _lengthBad ? context.tr('Use 10 to 100 characters.', 'कम्तीमा १० र बढीमा १०० अक्षर हुनुपर्छ।') : null;
    final mismatch = _mismatch ? context.tr('The two passwords do not match.', 'दुवै पासवर्ड मिलेनन्।') : null;
    final error = _error;
    final general = error == null || error.field('password') != null || error.field('token') != null ? null : error.message;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('Make a new password', 'नयाँ पासवर्ड बनाउने'), style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          context.tr('Use at least 10 characters.', 'कम्तीमा १० अक्षर प्रयोग गर्नुहोस्।'),
          style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PField(
                label: context.tr('New password', 'नयाँ पासवर्ड'),
                controller: _password,
                obscure: !_show,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                error: error?.field('password') ?? lengthError,
                onChanged: (_) => setState(() {}),
                suffix: IconButton(
                  tooltip: _show ? context.tr('Hide', 'लुकाउने') : context.tr('Show', 'देखाउने'),
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              const SizedBox(height: 14),
              PField(
                label: context.tr('Confirm new password', 'नयाँ पासवर्ड फेरि लेख्नुहोस्'),
                controller: _confirm,
                obscure: !_show,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                error: mismatch,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _canSave ? _save() : null,
              ),
              if (general != null) ...[
                const SizedBox(height: 12),
                AlertBox(general),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
