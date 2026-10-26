import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/settings/data/password.dart';
import 'package:pasal_mobile/features/settings/data/staff_repository.dart';

/// What the edit sheet can hand back to the list.
enum _StaffAction { remove }

/// The staff list. Owner only. Tap a person to change them or remove them.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final meId = ref.watch(sessionProvider).user?.id;

    return PageScaffold(
      title: context.tr('Staff', 'कर्मचारी'),
      scroll: false,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showPasalSheet<void>(
          context,
          title: context.tr('Add staff', 'कर्मचारी थप्ने'),
          builder: (_) => const _AddStaffSheet(),
        ),
        icon: const Icon(Icons.person_add_rounded),
        label: Text(context.tr('Add staff', 'कर्मचारी थप्ने')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(staffProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            AlertBox(
              context.tr('Staff cannot see buying prices, purchases, reports or VAT.', 'कर्मचारीले खरिद भाउ, खरिद, रिपोर्ट र भ्याट देख्न सक्दैनन्।'),
              tone: Tone.info,
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 12),
            AsyncBody(
              value: staff,
              onRetry: () => ref.invalidate(staffProvider),
              data: (users) {
                if (users.isEmpty) {
                  return SizedBox(
                    height: 320,
                    child: EmptyState(
                      icon: Icons.badge_rounded,
                      title: context.tr('No staff yet', 'अहिलेसम्म कर्मचारी छैन'),
                      text: context.tr('Add the people who work at the counter.', 'काउन्टरमा काम गर्ने मानिसहरू थप्नुहोस्।'),
                    ),
                  );
                }
                return ListCard(
                  children: [
                    for (final u in users)
                      ListRow(
                        leading: AvatarCircle(u.name, tone: u.isOwner ? Tone.primary : Tone.neutral),
                        title: u.id == meId ? '${u.name} (${context.tr('You', 'तपाईं')})' : u.name,
                        subtitle: u.email,
                        trailing: PBadge(
                          u.isOwner ? context.tr('Owner', 'मालिक') : context.tr('Staff', 'कर्मचारी'),
                          tone: u.isOwner ? Tone.primary : Tone.neutral,
                        ),
                        onTap: u.id == meId ? null : () => _openEdit(context, ref, u),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref, AppUser u) async {
    final action = await showPasalSheet<_StaffAction>(
      context,
      title: u.name,
      builder: (_) => _EditStaffSheet(user: u),
    );
    if (action != _StaffAction.remove || !context.mounted) return;
    await _confirmRemove(context, ref, u);
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, AppUser u) async {
    final ok = await confirmSheet(
      context,
      title: context.tr('Remove staff?', 'कर्मचारी हटाउने?'),
      message: context.tr('Removing signs ${u.name} out on every phone.', 'हटाउँदा ${u.name} सबै फोनबाट साइन आउट हुन्छन्।'),
      confirmLabel: context.tr('Remove', 'हटाउने'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final removed = await guard(
      () async {
        await ref.read(staffRepositoryProvider).remove(u.id);
        return true;
      },
      onError: (e) => showProblem(context, e.message),
    );
    if (!context.mounted || !(removed ?? false)) return;
    ref.invalidate(staffProvider);
    showToast(context, '${u.name} removed', '${u.name} हटाइयो');
  }
}

class _AddStaffSheet extends ConsumerStatefulWidget {
  const _AddStaffSheet();

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'staff';
  bool _showPw = false;
  bool _tried = false;
  bool _busy = false;
  ApiException? _error;
  ({String name, String password})? _created;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _tried = true);
    if (!passwordLengthOk(_password.text)) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final role = _role;
    setState(() {
      _busy = true;
      _error = null;
    });
    final added = await guard(
      () => ref.read(staffRepositoryProvider).add(name: name, email: email, password: password, role: role),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (added != null) {
      ref.invalidate(staffProvider);
      setState(() => _created = (name: added.name, password: password));
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    if (created != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCard(
            tone: Tone.good,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('${created.name} is added', '${created.name} थपियो'),
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(context.tr(
                  'Share this password with them now. It is not shown again.',
                  'यो पासवर्ड अहिले नै उनीसँग साझा गर्नुहोस्। यो फेरि देखाइने छैन।',
                )),
                const SizedBox(height: 8),
                SelectableText(
                  created.password,
                  style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: context.tr('Done', 'भयो'),
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    final passwordError = _tried && !passwordLengthOk(_password.text)
        ? context.tr('Use 10 to 100 characters', '१० देखि १०० अक्षरसम्मको पासवर्ड राख्नुहोस्')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PField(
          label: context.tr('Name', 'नाम'),
          controller: _name,
          hint: context.tr('Full name', 'पूरा नाम'),
          maxLength: 100,
          textInputAction: TextInputAction.next,
          error: _error?.field('name'),
        ),
        const SizedBox(height: 14),
        PField(
          label: context.tr('Email', 'इमेल'),
          controller: _email,
          hint: 'name@example.com',
          maxLength: 150,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          error: _error?.field('email'),
        ),
        const SizedBox(height: 14),
        _PasswordField(
          label: context.tr('Password', 'पासवर्ड'),
          controller: _password,
          showPw: _showPw,
          error: passwordError ?? _error?.field('password'),
          helper: context.tr('At least 10 characters.', 'कम्तीमा १० अक्षरको हुनुपर्छ।'),
          onToggle: () => setState(() => _showPw = !_showPw),
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _password.text = generatePassword();
            _showPw = true;
          }),
          icon: const Icon(Icons.key_rounded),
          label: Text(context.tr('Generate a password', 'पासवर्ड बनाउने')),
        ),
        const SizedBox(height: 14),
        _roleField(context, _role, (v) => setState(() => _role = v)),
        if (_error != null && _error!.errors.isEmpty) ...[
          const SizedBox(height: 12),
          AlertBox(_error!.message),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? context.tr('Adding…', 'थपिँदैछ…') : context.tr('Add staff', 'कर्मचारी थप्ने'),
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _EditStaffSheet extends ConsumerStatefulWidget {
  const _EditStaffSheet({required this.user});

  final AppUser user;

  @override
  ConsumerState<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends ConsumerState<_EditStaffSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _password = TextEditingController();
  late String _role;
  bool _showPw = false;
  bool _tried = false;
  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _email = TextEditingController(text: widget.user.email);
    _role = widget.user.role;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Only the fields that changed are sent.
  Future<void> _save() async {
    setState(() => _tried = true);
    final typed = _password.text.isNotEmpty;
    if (typed && !passwordLengthOk(_password.text)) return;
    final u = widget.user;
    final changes = <String, Object?>{
      if (_name.text.trim() != u.name) 'name': _name.text.trim(),
      if (_email.text.trim() != u.email) 'email': _email.text.trim(),
      if (_role != u.role) 'role': _role,
      if (typed) 'password': _password.text,
    };
    if (changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final signsOut = changes.containsKey('role') || changes.containsKey('password');
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await guard(
      () async {
        await ref.read(staffRepositoryProvider).update(u.id, changes);
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved ?? false) {
      ref.invalidate(staffProvider);
      showToast(
        context,
        signsOut ? 'Saved. ${u.name} is signed out on every phone.' : 'Saved',
        signsOut ? 'सेभ भयो। ${u.name} सबै फोनबाट साइन आउट भए।' : 'सेभ भयो',
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final roleChanged = _role != u.role;
    final typed = _password.text.isNotEmpty;
    final passwordError = _tried && typed && !passwordLengthOk(_password.text)
        ? context.tr('Use 10 to 100 characters', '१० देखि १०० अक्षरसम्मको पासवर्ड राख्नुहोस्')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PField(
          label: context.tr('Name', 'नाम'),
          controller: _name,
          maxLength: 100,
          textInputAction: TextInputAction.next,
          error: _error?.field('name'),
        ),
        const SizedBox(height: 14),
        PField(
          label: context.tr('Email', 'इमेल'),
          controller: _email,
          maxLength: 150,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          error: _error?.field('email'),
        ),
        const SizedBox(height: 14),
        _roleField(context, _role, (v) => setState(() => _role = v)),
        const SizedBox(height: 14),
        _PasswordField(
          label: context.tr('New password (leave empty to keep)', 'नयाँ पासवर्ड (खाली छोड्नुहोस्)'),
          controller: _password,
          showPw: _showPw,
          error: passwordError ?? _error?.field('password'),
          onToggle: () => setState(() => _showPw = !_showPw),
          onChanged: () => setState(() {}),
        ),
        if (roleChanged || typed) ...[
          const SizedBox(height: 12),
          AlertBox(
            context.tr('${u.name} is signed out on every phone when you save.', 'सेभ गर्दा ${u.name} सबै फोनबाट साइन आउट हुन्छन्।'),
            tone: Tone.warn,
            icon: Icons.warning_amber_rounded,
          ),
        ],
        if (_error != null && _error!.errors.isEmpty) ...[
          const SizedBox(height: 12),
          AlertBox(_error!.message),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save', 'सेभ गर्ने'),
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _save,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => Navigator.of(context).pop(_StaffAction.remove),
          icon: Icon(Icons.person_remove_rounded, color: context.colors.bad),
          label: Text(context.tr('Remove staff', 'कर्मचारी हटाउने'), style: TextStyle(color: context.colors.bad)),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.showPw,
    required this.onToggle,
    required this.onChanged,
    this.error,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final bool showPw;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return PField(
      label: label,
      controller: controller,
      obscure: !showPw,
      error: error,
      helper: helper,
      onChanged: (_) => onChanged(),
      suffix: IconButton(
        tooltip: showPw ? context.tr('Hide', 'लुकाउने') : context.tr('Show', 'देखाउने'),
        icon: Icon(showPw ? Icons.visibility_off_rounded : Icons.visibility_rounded),
        onPressed: onToggle,
      ),
    );
  }
}

Widget _roleField(BuildContext context, String value, ValueChanged<String> onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          context.tr('Role', 'भूमिका'),
          style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
        ),
      ),
      Seg<String>(
        value: value,
        onChanged: onChanged,
        options: {'owner': context.tr('Owner', 'मालिक'), 'staff': context.tr('Staff', 'कर्मचारी')},
      ),
    ],
  );
}
