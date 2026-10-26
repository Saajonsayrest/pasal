import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/guard.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/settings/data/shop_repository.dart';

/// Shop name, PAN, phone, address, VAT rate and the bill footer. Owner only.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _name = TextEditingController();
  final _pan = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _vat = TextEditingController();
  final _footer = TextEditingController();
  bool _filled = false;
  bool _busy = false;
  ApiException? _error;
  String? _vatError;

  @override
  void initState() {
    super.initState();
    _footer.text = readBillFooter(ref.read(sharedPrefsProvider));
  }

  @override
  void dispose() {
    for (final c in [_name, _pan, _phone, _address, _vat, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Runs once, before the fields are built, so typing is never overwritten by a later refresh.
  void _fill(Business b) {
    _filled = true;
    _name.text = b.name;
    _pan.text = b.pan ?? '';
    _phone.text = b.phone ?? '';
    _address.text = b.address ?? '';
    _vat.text = _vatText(b.vatRate);
  }

  static String _vatText(double rate) => rate == rate.roundToDouble() ? rate.toInt().toString() : rate.toString();

  /// "13" or "12.5", up to two decimals and at most 100. Null when the text is not a rate.
  static double? _parseVat(String text) {
    final t = text.trim();
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(t)) return null;
    final v = double.parse(t);
    return v <= 100 ? v : null;
  }

  static String? _orNull(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final rate = _parseVat(_vat.text);
    if (rate == null) {
      setState(() => _vatError = context.tr('Type a rate from 0 to 100', 'दर ० देखि १०० सम्म लेख्नुहोस्'));
      return;
    }
    setState(() {
      _vatError = null;
      _error = null;
      _busy = true;
    });
    final repo = ref.read(shopRepositoryProvider);
    final saved = await guard(
      () async {
        await repo.update(
          name: _name.text.trim(),
          pan: _orNull(_pan.text),
          phone: _orNull(_phone.text),
          address: _orNull(_address.text),
          vatRate: rate,
        );
        await ref.read(sessionProvider.notifier).refresh();
        return true;
      },
      onError: (e) => _error = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved ?? false) {
      await writeBillFooter(ref.read(sharedPrefsProvider), _footer.text);
      if (!mounted) return;
      ref.invalidate(shopProvider);
      showToast(context, 'Shop details saved', 'पसलको विवरण सेभ भयो');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(shopProvider);
    if (!_filled && shop.hasValue) _fill(shop.requireValue);

    return PageScaffold(
      title: context.tr('Shop details', 'पसलको विवरण'),
      bottom: shop.hasValue
          ? PrimaryButton(
              label: _busy ? context.tr('Saving…', 'सेभ हुँदैछ…') : context.tr('Save', 'सेभ गर्ने'),
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: _save,
            )
          : null,
      body: AsyncBody(
        value: shop,
        onRetry: () => ref.invalidate(shopProvider),
        data: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Shop logo upload is not available yet.', 'पसलको लोगो अपलोड अहिले उपलब्ध छैन।'),
              style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            PCard(
              child: Column(
                children: [
                  PField(
                    label: context.tr('Shop name', 'पसलको नाम'),
                    controller: _name,
                    maxLength: 150,
                    textInputAction: TextInputAction.next,
                    error: _error?.field('name'),
                  ),
                  const SizedBox(height: 14),
                  PField(
                    label: context.tr('PAN number', 'PAN नम्बर'),
                    controller: _pan,
                    maxLength: 20,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    error: _error?.field('pan'),
                  ),
                  const SizedBox(height: 14),
                  PField(
                    label: context.tr('Phone', 'फोन'),
                    controller: _phone,
                    maxLength: 30,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    error: _error?.field('phone'),
                  ),
                  const SizedBox(height: 14),
                  PField(
                    label: context.tr('Address', 'ठेगाना'),
                    controller: _address,
                    maxLength: 255,
                    textInputAction: TextInputAction.next,
                    error: _error?.field('address'),
                  ),
                  const SizedBox(height: 14),
                  PField(
                    label: context.tr('VAT rate %', 'भ्याट दर %'),
                    controller: _vat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    textInputAction: TextInputAction.next,
                    error: _vatError ?? _error?.field('vat_rate'),
                    helper: context.tr('Applies to new sales only.', 'नयाँ बिक्रीमा मात्र लागू हुन्छ।'),
                  ),
                  const SizedBox(height: 14),
                  PField(
                    label: context.tr('Bill footer text', 'बिलको तलको लेख'),
                    controller: _footer,
                    maxLines: 2,
                    maxLength: 300,
                    helper: context.tr(
                      'Saved on this phone only. Shown at the bottom of each bill.',
                      'यो फोनमा मात्र सेभ हुन्छ। हरेक बिलको तलमा देखिन्छ।',
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null && _error!.errors.isEmpty) ...[
              const SizedBox(height: 12),
              AlertBox(_error!.message),
            ],
          ],
        ),
      ),
    );
  }
}
