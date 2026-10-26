import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/auth/data/account_repository.dart';

/// A4. The person's own account: change password, app look, sign out, sign out on all devices.
/// After a sign out the router sends the person to the login screen by itself.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final saved = await showPasalSheet<bool>(
      context,
      title: context.tr('Change password', 'पासवर्ड बदल्ने'),
      builder: (_) => const _ChangePasswordForm(),
    );
    if ((saved ?? false) && context.mounted) {
      showToast(context, 'Password changed', 'पासवर्ड बदलियो');
    }
  }

  /// The toast is shown before the sign out, while this screen is still on the screen.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    showToast(context, 'Signed out', 'साइन आउट भयो');
    await ref.read(sessionProvider.notifier).logout();
  }

  Future<void> _signOutEverywhere(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: context.tr('Sign out on all devices?', 'सबै यन्त्रबाट साइन आउट?'),
      message: context.tr(
        'This signs out every phone that uses this account. Use it if you lost a phone. You must log in again on each phone.',
        'यसले यो खाता चलाउने सबै फोनबाट साइन आउट गर्छ। फोन हराएको भए यो प्रयोग गर्नुहोस्। हरेक फोनमा फेरि लग इन गर्नुपर्छ।',
      ),
      confirmLabel: context.tr('Sign out everywhere', 'सबै ठाउँबाट साइन आउट'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    showToast(context, 'Signed out on all devices', 'सबै यन्त्रबाट साइन आउट भयो');
    await ref.read(sessionProvider.notifier).logout(everywhere: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final name = user?.name ?? '';

    return PageScaffold(
      title: context.tr('My profile', 'मेरो प्रोफाइल'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCard(
            child: Column(
              children: [
                AvatarCircle(name, size: 88),
                const SizedBox(height: 12),
                Text(name, textAlign: TextAlign.center, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(user?.email ?? '', style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant)),
                Text(session.business?.name ?? 'PASAL', style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                if (session.isOwner) PBadge(context.tr('Owner', 'मालिक'), tone: Tone.primary) else PBadge(context.tr('Staff', 'कर्मचारी'), tone: Tone.info),
              ],
            ),
          ),
          SectionTitle(context.tr('Security', 'सुरक्षा')),
          const SizedBox(height: 8),
          ListCard(
            children: [
              ListRow(
                leading: const IconTile(Icons.key_rounded, tone: Tone.neutral, size: 40),
                title: context.tr('Change password', 'पासवर्ड बदल्ने'),
                onTap: () => _changePassword(context),
              ),
              ListRow(
                leading: const IconTile(Icons.palette_rounded, tone: Tone.neutral, size: 40),
                title: context.tr('App look and language', 'एपको रूप र भाषा'),
                onTap: () => context.push('/settings/look'),
              ),
            ],
          ),
          SectionTitle(context.tr('Signed in', 'साइन इन')),
          const SizedBox(height: 8),
          ListCard(
            children: [
              ListRow(
                leading: const IconTile(Icons.logout_rounded, tone: Tone.neutral, size: 40),
                title: context.tr('Sign out', 'साइन आउट'),
                onTap: () => _signOut(context, ref),
              ),
              ListRow(
                leading: const IconTile(Icons.devices_rounded, tone: Tone.bad, size: 40),
                title: context.tr('Sign out on all devices', 'सबै यन्त्रबाट साइन आउट'),
                subtitle: context.tr('Use it if you lost a phone', 'फोन हराएको भए यो प्रयोग गर्नुहोस्'),
                onTap: () => _signOutEverywhere(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The change password sheet. Closes with `true` when the password was saved.
class _ChangePasswordForm extends ConsumerStatefulWidget {
  const _ChangePasswordForm();

  @override
  ConsumerState<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<_ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  bool get _lengthBad => _next.text.isNotEmpty && (_next.text.length < 10 || _next.text.length > 100);
  bool get _canSave => !_busy && _current.text.isNotEmpty && _next.text.isNotEmpty;

  Future<void> _save() async {
    if (_lengthBad) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await guard(
      () async {
        await ref.read(accountRepositoryProvider).changePassword(currentPassword: _current.text, password: _next.text);
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    if (ok ?? false) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final lengthError = _lengthBad ? context.tr('Use 10 to 100 characters.', 'कम्तीमा १० र बढीमा १०० अक्षर हुनुपर्छ।') : null;
    final general = error?.general;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PField(
          label: context.tr('Current password', 'हालको पासवर्ड'),
          controller: _current,
          obscure: true,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.next,
          error: error?.field('current_password'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        PField(
          label: context.tr('New password', 'नयाँ पासवर्ड'),
          controller: _next,
          obscure: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          helper: context.tr('At least 10 characters.', 'कम्तीमा १० अक्षरको हुनुपर्छ।'),
          error: error?.field('password') ?? lengthError,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _canSave ? _save() : null,
        ),
        if (general != null) ...[
          const SizedBox(height: 12),
          AlertBox(general),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save new password', 'नयाँ पासवर्ड सेभ गर्ने'),
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _canSave ? _save : null,
        ),
      ],
    );
  }
}
