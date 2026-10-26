import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/settings/settings.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';

/// A1. Log in. Reference screen for forms: local state, a busy flag, server errors under the fields.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await guard(
      () async {
        await ref.read(sessionProvider.notifier).login(_email.text.trim(), _password.text);
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) {
      final name = ref.read(sessionProvider).user?.name.split(' ').first ?? '';
      showToast(context, 'Logged in. Welcome, $name.', 'लग इन भयो। स्वागत छ, $name।');
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final canSubmit = !_busy && _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(label: const Text('English'), selected: !settings.ne, showCheckmark: false, onSelected: (_) => ref.read(settingsProvider.notifier).setNepali(false)),
                      ChoiceChip(label: const Text('नेपाली'), selected: settings.ne, showCheckmark: false, onSelected: (_) => ref.read(settingsProvider.notifier).setNepali(true)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: context.scheme.primary, borderRadius: BorderRadius.circular(28)),
                    child: Text('प', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: context.scheme.onPrimary)),
                  ),
                ),
                const SizedBox(height: 14),
                Center(child: Text('PASAL', style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    context.tr('Stock, sales and credit, made simple', 'स्टक, बिक्री र उधारोको सजिलो हिसाब'),
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 24),
                PCard(
                  child: Column(
                    children: [
                      PField(
                        label: context.tr('Email', 'इमेल'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        error: _error?.field('email'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      PField(
                        label: context.tr('Password', 'पासवर्ड'),
                        controller: _password,
                        obscure: !_show,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        error: _error?.field('password'),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => canSubmit ? _submit() : null,
                        suffix: IconButton(
                          tooltip: _show ? context.tr('Hide', 'लुकाउने') : context.tr('Show', 'देखाउने'),
                          icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                          onPressed: () => setState(() => _show = !_show),
                        ),
                      ),
                      if (_error?.general != null && _error!.errors.isEmpty) ...[
                        const SizedBox(height: 12),
                        AlertBox(_error!.message),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: Text(context.tr('Forgot password?', 'पासवर्ड बिर्सनुभयो?')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _busy ? context.tr('Logging in…', 'लग इन हुँदैछ…') : context.tr('Log in', 'लग इन'),
                  icon: Icons.login_rounded,
                  busy: _busy,
                  onPressed: canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
