import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/utils/money.dart';
import 'package:pasal_mobile/core/widgets/amount_pad.dart';
import 'package:pasal_mobile/core/widgets/bs_date.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/money/data/money_repository.dart';
import 'package:pasal_mobile/features/money/presentation/money_labels.dart';

/// G2. Add an expense: amount on the pad, what it was for, a category, the date.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _title = TextEditingController();
  final _category = TextEditingController();
  String _amount = '';
  String _date = todayAd();
  bool _tried = false;
  bool _busy = false;
  ApiException? _error;

  /// One key per attempt. A retry of the same body reuses it. Any change to the form makes a new one.
  String _key = newKey();

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    super.dispose();
  }

  void _edited([VoidCallback? change]) => setState(() {
        change?.call();
        _key = newKey();
      });

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/expenses');
    }
  }

  Future<void> _save() async {
    final paisa = toPaisa(_amount);
    final title = _title.text.trim();
    if (paisa == null || paisa < 1 || title.isEmpty) {
      setState(() => _tried = true);
      return;
    }
    final category = categoryKey(_category.text);
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await guard(
      () => ref.read(moneyRepositoryProvider).addExpense(
            title: title,
            category: category.isEmpty ? null : category,
            amount: paisa,
            spentAt: _date,
            key: _key,
          ),
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    ref.invalidate(expensesProvider);
    showToast(context, 'Expense saved', 'खर्च सेभ भयो');
    _back();
  }

  /// The preset whose name is typed, so its chip stays lit.
  String _presetFor(String typed) {
    for (final c in expenseCategories) {
      if (c.en.toLowerCase() == typed) {
        return c.en;
      }
    }
    return '';
  }

  Widget _fieldError(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(text, style: context.text.bodySmall?.copyWith(color: context.colors.bad)),
      );

  @override
  Widget build(BuildContext context) {
    final paisa = toPaisa(_amount);
    final amountBad = paisa == null || paisa < 1;
    final amountError = _tried && amountBad
        ? context.tr('Type the amount in rupees', 'रकम रुपैयाँमा लेख्नुहोस्')
        : _error?.field('amount');
    final titleError = _tried && _title.text.trim().isEmpty
        ? context.tr('Write what it was for', 'किन खर्च भयो लेख्नुहोस्')
        : _error?.field('title');
    final general = _error != null && _error!.errors.isEmpty ? _error!.message : null;

    return PageScaffold(
      title: context.tr('Add expense', 'खर्च थप्ने'),
      bottom: Row(
        children: [
          Expanded(
            flex: 10,
            child: OutlinedButton(onPressed: _back, child: Text(context.tr('Back', 'फर्कनुहोस्'))),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 14,
            child: PrimaryButton(
              label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save expense', 'खर्च सेभ गर्ने'),
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCard(
            child: Column(
              children: [
                AmountPad(value: _amount, onChanged: (v) => _edited(() => _amount = v)),
                if (amountError != null) _fieldError(amountError),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PField(
            label: context.tr('What was it for?', 'यो किन खर्च भयो?'),
            controller: _title,
            hint: context.tr('For example: Electricity', 'उदाहरण: बिजुली'),
            maxLength: 150,
            error: titleError,
            onChanged: (_) => _edited(),
          ),
          const SizedBox(height: 14),
          PField(
            label: context.tr('Category', 'वर्ग'),
            controller: _category,
            hint: context.tr('Type a category', 'वर्ग लेख्नुहोस्'),
            helper: context.tr('Pick one or type your own', 'एउटा छान्नुहोस् वा आफैँ लेख्नुहोस्'),
            maxLength: 50,
            error: _error?.field('category'),
            onChanged: (_) => _edited(),
          ),
          const SizedBox(height: 10),
          ChipsRow<String>(
            value: _presetFor(categoryKey(_category.text)),
            onChanged: (v) => _edited(() {
              _category.text = v;
            }),
            options: {for (final c in expenseCategories) c.en: context.tr(c.en, c.ne)},
          ),
          const SizedBox(height: 14),
          BsDateField(
            label: context.tr('Date', 'मिति'),
            value: _date,
            max: todayAd(),
            onChanged: (v) => _edited(() => _date = v),
          ),
          if (_error?.field('spent_at') != null) _fieldError(_error!.field('spent_at')!),
          if (general != null) ...[
            const SizedBox(height: 12),
            AlertBox(general),
          ],
        ],
      ),
    );
  }
}
