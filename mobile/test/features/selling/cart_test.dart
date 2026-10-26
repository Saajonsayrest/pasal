import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/features/selling/data/cart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'selling_fixtures.dart';

Future<SharedPreferences> _freshPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<(SharedPreferences, ProviderContainer)> _open([SharedPreferences? existing]) async {
  final prefs = existing ?? await _freshPrefs();
  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return (prefs, container);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cart maths', () {
    final rice = riceItem();
    final milk = milkItem();

    test('adds the lines, then takes the discount off the subtotal', () {
      final lines = [CartLine(item: rice, qty: 2), CartLine(item: milk, qty: 1)];
      expect(subtotalOf(lines), 27600);
      expect(totalOf(27600, 1000), 26600);
      expect(totalOf(100, 500), 0);
    });

    test('reads the balance as total minus paid, and paid null as paid in full', () {
      expect(balanceOf(11300, null), 0);
      expect(balanceOf(11300, 5000), 6300);
      expect(balanceOf(11300, 0), 11300);
    });

    test('splits VAT the way the bill does for a VAT item', () {
      expect(vatBreakdown([CartLine(item: rice, qty: 1)], 0, 13), const VatSplit(taxable: 10000, vat: 1300, exempt: 0, total: 11300));
    });

    test('takes the discount off the VAT part first', () {
      expect(vatBreakdown([CartLine(item: rice, qty: 1)], 1130, 13), const VatSplit(taxable: 9000, vat: 1170, exempt: 0, total: 10170));
    });

    test('keeps the split equal to the total when VAT and no-VAT items mix', () {
      final lines = [
        CartLine(item: const CartItem(id: 7, name: 'Rice 5kg', unit: 'pcs', sellPrice: 10000, quantity: 3, vatApplies: true), qty: 1),
        CartLine(item: milk, qty: 1),
      ];
      final split = vatBreakdown(lines, 0, 13);
      expect(split.taxable + split.vat + split.exempt, split.total);
      expect(split, const VatSplit(taxable: 8850, vat: 1150, exempt: 5000, total: 15000));
    });

    test('rounds the value of part of a line to whole paisa, half up', () {
      expect(returnValue(1, 1050, 2), 525);
      expect(returnValue(1, 100, 3), 33);
      expect(returnValue(2, 100, 3), 67);
      expect(returnValue(1, 5, 2), 3);
      expect(returnValue(0, 5, 2), 0);
    });

    test('pays the debt down first and gives the rest back in cash', () {
      expect(returnPreview(105000, 124000), const ReturnSplit(debtDown: 105000, cashBack: 0, balanceAfter: 19000));
      expect(returnPreview(105000, 50000), const ReturnSplit(debtDown: 50000, cashBack: 55000, balanceAfter: 0));
      expect(returnPreview(30000, 0), const ReturnSplit(debtDown: 0, cashBack: 30000, balanceAfter: 0));
    });

    test('flags a credit sale only when it pushes the customer past the limit', () {
      expect(overLimit(4000, 1500, 5000), isTrue);
      expect(overLimit(4000, 500, 5000), isFalse);
      expect(overLimit(4000, 0, 0), isFalse);
      expect(overLimit(4000, 1500, null), isFalse);
    });
  });

  group('cart store', () {
    test('never adds above the stock', () async {
      final (_, c) = await _open();
      final cart = c.read(cartProvider.notifier);
      final rice = riceItem();
      expect(cart.add(rice), isTrue);
      expect(cart.add(rice), isTrue);
      expect(cart.add(rice), isTrue);
      expect(cart.add(rice), isFalse);
      expect(c.read(cartProvider).count, 3);
      expect(c.read(cartProvider).canCheckout, isTrue);
    });

    test('refuses an item with no stock', () async {
      final (_, c) = await _open();
      expect(c.read(cartProvider.notifier).add(riceItem(qty: 0)), isFalse);
      expect(c.read(cartProvider).lines, isEmpty);
    });

    test('needs a customer when the paid amount is less than the total', () async {
      final (_, c) = await _open();
      final cart = c.read(cartProvider.notifier);
      cart.add(riceItem());
      cart.setPaid(5000);
      expect(c.read(cartProvider).balance, 6300);
      expect(c.read(cartProvider).canCheckout, isFalse);
      cart.setCustomer(hariCustomer());
      expect(c.read(cartProvider).canCheckout, isTrue);
      cart.setPaid(null);
      cart.setCustomer(null);
      expect(c.read(cartProvider).canCheckout, isTrue);
    });

    test('holds the cart and restores it, keeping the customer name as the label', () async {
      final (prefs, c) = await _open();
      final cart = c.read(cartProvider.notifier);
      cart.add(milkItem());
      cart.setCustomer(hariCustomer());
      final held = cart.hold();
      expect(held?.label, 'Hari');
      expect(c.read(cartProvider).lines, isEmpty);
      expect(c.read(cartProvider).held, hasLength(1));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('pasal_held'), contains('Hari'));

      expect(cart.restore(held!.id), isTrue);
      expect(c.read(cartProvider).count, 1);
      expect(c.read(cartProvider).customer?.name, 'Hari');
      expect(c.read(cartProvider).held, isEmpty);
    });

    test('keeps the current cart when a held cart is restored over it', () async {
      final (_, c) = await _open();
      final cart = c.read(cartProvider.notifier);
      cart.add(milkItem());
      final first = cart.hold('First');
      cart.add(riceItem());
      expect(cart.restore(first!.id), isTrue);
      expect(c.read(cartProvider).lines.map((l) => l.item.name), ['Milk 500ml']);
      expect(c.read(cartProvider).held.map((h) => h.lines.first.item.name), ['Rice 5kg']);
    });

    test('discards a held cart', () async {
      final (_, c) = await _open();
      final cart = c.read(cartProvider.notifier);
      cart.add(milkItem());
      final held = cart.hold();
      cart.discard(held!.id);
      expect(c.read(cartProvider).held, isEmpty);
    });

    test('keeps the cart after a restart, and clearCartData removes it', () async {
      final (prefs, first) = await _open();
      first.read(cartProvider.notifier).add(riceItem());
      await Future<void>.delayed(Duration.zero);

      final (_, second) = await _open(prefs);
      expect(second.read(cartProvider).count, 1);
      expect(second.read(cartProvider).lines.first.item.name, 'Rice 5kg');

      await clearCartData(prefs);
      final (_, third) = await _open(prefs);
      expect(third.read(cartProvider).lines, isEmpty);
      expect(third.read(cartProvider).held, isEmpty);
    });
  });
}
