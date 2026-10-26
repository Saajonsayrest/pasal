import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/sheets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/suppliers/data/supplier_repository.dart';

/// F1e and F1n. Add a supplier (no [id]) or edit one. Delete is at the bottom of the edit screen.
class SupplierFormScreen extends ConsumerWidget {
  const SupplierFormScreen({this.id, super.key});

  final int? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = id;
    if (supplierId == null) return const _SupplierEditor(id: null, initial: null);

    final current = ref.watch(supplierProvider(supplierId));
    if (current.hasValue) return _SupplierEditor(id: supplierId, initial: current.requireValue);
    return PageScaffold(
      title: context.tr('Edit supplier', 'डिलर सच्याउने'),
      scroll: false,
      body: current.hasError
          ? ErrorView(error: current.error!, onRetry: () => ref.invalidate(supplierProvider(supplierId)))
          : const SkeletonList(),
    );
  }
}

class _SupplierEditor extends ConsumerStatefulWidget {
  const _SupplierEditor({required this.id, required this.initial});

  final int? id;
  final Supplier? initial;

  @override
  ConsumerState<_SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends ConsumerState<_SupplierEditor> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _pan = TextEditingController(text: widget.initial?.pan);
  late final _note = TextEditingController(text: widget.initial?.note);
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _pan.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Json _body() => {
        'name': _name.text.trim(),
        'phone': _optional(_phone),
        'address': _optional(_address),
        'pan': _optional(_pan),
        'note': _optional(_note),
      };

  void _refreshCaches() {
    ref.invalidate(suppliersProvider);
    ref.invalidate(allSuppliersProvider);
    final id = widget.id;
    if (id != null) ref.invalidate(supplierProvider(id));
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await guard(
      () => ref.read(supplierRepositoryProvider).save(widget.id, _body()),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    _refreshCaches();
    showToast(context, 'Supplier saved', 'डिलर सेभ भयो');
    context.pushReplacement('/suppliers/${saved.id}');
  }

  Future<void> _delete() async {
    final id = widget.id;
    if (id == null) return;
    final ok = await confirmSheet(
      context,
      title: context.tr('Delete supplier?', 'डिलर हटाउने हो?'),
      message: context.tr(
        'The supplier will be hidden from lists and from new purchases. Old purchases keep the name.',
        'डिलर सूचीबाट र नयाँ खरिदबाट लुक्नेछ। पुराना खरिदमा नाम रहन्छ।',
      ),
      confirmLabel: context.tr('Delete supplier', 'डिलर हटाउने'),
      danger: true,
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final done = await guard(
      () async {
        await ref.read(supplierRepositoryProvider).delete(id);
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done ?? false) {
      _refreshCaches();
      showToast(context, 'Supplier deleted', 'डिलर हटाइयो');
      context.go('/suppliers');
    }
  }

  String? get _generalProblem {
    final err = _error;
    if (err == null) return null;
    if (err.errors.isEmpty) return err.message;
    for (final entry in err.errors.entries) {
      if (!const {'name', 'phone', 'address', 'pan', 'note'}.contains(entry.key) && entry.value.isNotEmpty) return entry.value.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.id == null;
    final canSave = !_busy && _name.text.trim().isNotEmpty;

    return PageScaffold(
      title: isNew ? context.tr('Add supplier', 'डिलर थप्ने') : context.tr('Edit supplier', 'डिलर सच्याउने'),
      bottom: PrimaryButton(
        label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save', 'सेभ गर्ने'),
        icon: Icons.check_rounded,
        busy: _busy,
        onPressed: canSave ? _save : null,
      ),
      body: Column(
        children: [
          PField(
            label: context.tr('Supplier name (required)', 'डिलरको नाम (आवश्यक)'),
            hint: context.tr('For example: Everest Traders', 'जस्तै: एभरेस्ट ट्रेडर्स'),
            controller: _name,
            error: _error?.field('name'),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          PField(
            label: context.tr('Phone', 'फोन'),
            hint: '98000000xx',
            controller: _phone,
            keyboardType: TextInputType.phone,
            error: _error?.field('phone'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          PField(
            label: context.tr('Address', 'ठेगाना'),
            controller: _address,
            maxLines: 2,
            error: _error?.field('address'),
          ),
          const SizedBox(height: 14),
          PField(
            label: context.tr('PAN number (optional)', 'PAN नम्बर (ऐच्छिक)'),
            hint: '600000000',
            controller: _pan,
            keyboardType: TextInputType.number,
            error: _error?.field('pan'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          PField(
            label: context.tr('Note (optional)', 'नोट (ऐच्छिक)'),
            hint: context.tr('For example: comes twice a week', 'जस्तै: हप्ताको दुई पटक आउँछन्'),
            controller: _note,
            maxLines: 2,
            error: _error?.field('note'),
          ),
          if (_generalProblem != null) ...[
            const SizedBox(height: 14),
            AlertBox(_generalProblem!),
          ],
          if (!isNew) ...[
            const SizedBox(height: 24),
            ListCard(
              children: [
                ListRow(
                  leading: const IconTile(Icons.delete_rounded, tone: Tone.bad),
                  title: context.tr('Delete supplier', 'डिलर हटाउने'),
                  subtitle: context.tr('Old purchases keep the name.', 'पुराना खरिदमा नाम रहन्छ।'),
                  chevron: false,
                  onTap: _busy ? null : _delete,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
