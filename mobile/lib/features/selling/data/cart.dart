import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The selling cart: lines, bill discount, customer and payment. Money is whole paisa.
/// The cart and the held carts are saved on the phone, so an app restart does not lose them.
/// Matches web/src/lib/cart.svelte.ts.

const cartMaxLines = 100;

/// Payment methods at the counter, in the order the screens show them.
const cartMethods = ['cash', 'qr', 'bank', 'card'];

const _cartKey = 'pasal_cart';
const _heldKey = 'pasal_held';

/// Removes the saved cart and held carts. Call it on logout, then `ref.invalidate(cartProvider)`.
Future<void> clearCartData(SharedPreferences prefs) async {
  await prefs.remove(_cartKey);
  await prefs.remove(_heldKey);
}

/// An item as it was when it went into the cart. The price and stock seen then are kept.
class CartItem {
  const CartItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.sellPrice,
    required this.quantity,
    required this.vatApplies,
    this.photoUrl,
  });

  factory CartItem.of(Item item) => CartItem(
        id: item.id,
        name: item.name,
        unit: item.unit,
        sellPrice: item.sellPrice,
        quantity: item.quantity,
        vatApplies: item.vatApplies,
        photoUrl: item.photoUrl,
      );

  factory CartItem.fromJson(Json j) => CartItem(
        id: j['id'] as int,
        name: j['name'] as String,
        unit: j['unit'] as String,
        sellPrice: j['sell_price'] as int,
        quantity: j['quantity'] as int,
        vatApplies: j['vat_applies'] as bool,
        photoUrl: j['photo_url'] as String?,
      );

  Json toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'sell_price': sellPrice,
        'quantity': quantity,
        'vat_applies': vatApplies,
        'photo_url': photoUrl,
      };

  final int id;
  final String name;
  final String unit;

  /// Includes VAT.
  final int sellPrice;

  /// Stock when the item was added.
  final int quantity;
  final bool vatApplies;
  final String? photoUrl;
}

class CartLine {
  const CartLine({required this.item, required this.qty});

  factory CartLine.fromJson(Json j) => CartLine(item: CartItem.fromJson(j['item'] as Json), qty: j['qty'] as int);

  Json toJson() => {'item': item.toJson(), 'qty': qty};

  final CartItem item;
  final int qty;
}

class HeldCart {
  const HeldCart({
    required this.id,
    required this.label,
    required this.at,
    required this.lines,
    required this.discount,
    required this.paid,
    required this.method,
    required this.note,
    this.customer,
  });

  factory HeldCart.fromJson(Json j) => HeldCart(
        id: j['id'] as String,
        label: j['label'] as String,
        at: j['at'] as String,
        lines: [for (final l in j['lines'] as List<dynamic>) CartLine.fromJson(l as Json)],
        discount: j['discount'] as int,
        paid: j['paid'] as int?,
        method: j['method'] as String,
        note: j['note'] as String,
        customer: j['customer'] == null ? null : Customer.fromJson(j['customer'] as Json),
      );

  Json toJson() => {
        'id': id,
        'label': label,
        'at': at,
        'lines': [for (final l in lines) l.toJson()],
        'discount': discount,
        'paid': paid,
        'method': method,
        'note': note,
        'customer': customerToJson(customer),
      };

  final String id;

  /// The name typed when the cart was held, else the customer's name.
  final String label;

  /// ISO time when the cart was held.
  final String at;
  final List<CartLine> lines;
  final int discount;
  final Customer? customer;

  /// Null means paid in full.
  final int? paid;
  final String method;
  final String note;
}

class VatSplit {
  const VatSplit({required this.taxable, required this.vat, required this.exempt, required this.total});

  final int taxable;
  final int vat;
  final int exempt;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is VatSplit && other.taxable == taxable && other.vat == vat && other.exempt == exempt && other.total == total;

  @override
  int get hashCode => Object.hash(taxable, vat, exempt, total);

  @override
  String toString() => 'VatSplit($taxable, $vat, $exempt, $total)';
}

class ReturnSplit {
  const ReturnSplit({required this.debtDown, required this.cashBack, required this.balanceAfter});

  final int debtDown;
  final int cashBack;
  final int balanceAfter;

  @override
  bool operator ==(Object other) =>
      other is ReturnSplit && other.debtDown == debtDown && other.cashBack == cashBack && other.balanceAfter == balanceAfter;

  @override
  int get hashCode => Object.hash(debtDown, cashBack, balanceAfter);

  @override
  String toString() => 'ReturnSplit($debtDown, $cashBack, $balanceAfter)';
}

Json? customerToJson(Customer? c) => c == null
    ? null
    : {
        'id': c.id,
        'name': c.name,
        'phone': c.phone,
        'address': c.address,
        'pan': c.pan,
        'credit_limit': c.creditLimit,
        'owes': c.owes,
        'last_sale_at': c.lastSaleAt,
        'oldest_unpaid_at': c.oldestUnpaidAt,
      };

int lineAmount(CartLine line) => line.qty * line.item.sellPrice;

int countOf(List<CartLine> lines) => lines.fold(0, (sum, line) => sum + line.qty);

int subtotalOf(List<CartLine> lines) => lines.fold(0, (sum, line) => sum + lineAmount(line));

int totalOf(int subtotal, int discount) => subtotal - discount < 0 ? 0 : subtotal - discount;

/// Paid null means paid in full.
int balanceOf(int total, int? paid) => total - (paid ?? total);

/// Whole-number division rounded half up. Works on big numbers without losing paisa.
int _roundDiv(BigInt n, BigInt d) => ((BigInt.from(2) * n + d) ~/ (BigInt.from(2) * d)).toInt();

/// The browser's estimate of the VAT on a bill. The bill from the server is the final figure.
/// The discount is shared by price, the same way the server does it.
VatSplit vatBreakdown(List<CartLine> lines, int discount, double rate) {
  final subtotal = subtotalOf(lines);
  final vatable = lines.where((l) => l.item.vatApplies).fold(0, (sum, l) => sum + lineAmount(l));
  final exempt = subtotal - vatable;
  final share = subtotal > 0 ? _roundDiv(BigInt.from(discount) * BigInt.from(vatable), BigInt.from(subtotal)) : 0;
  final vatableAfter = vatable - share;
  final exemptAfter = exempt - (discount - share);
  // rate is a percent such as 13. Scaled by 100 twice to stay in whole numbers.
  final rateX100 = (rate * 100).round();
  final taxable = _roundDiv(BigInt.from(vatableAfter) * BigInt.from(10000), BigInt.from(10000 + rateX100));
  return VatSplit(
    taxable: taxable,
    vat: vatableAfter - taxable,
    exempt: exemptAfter,
    total: vatableAfter + exemptAfter,
  );
}

/// Value of `qty` units of a sold line that cost [lineTotal] for [quantity] units. Half up, whole paisa.
int returnValue(int qty, int lineTotal, int quantity) {
  if (qty <= 0 || quantity <= 0) return 0;
  final q = BigInt.from(quantity);
  final n = BigInt.from(qty) * BigInt.from(lineTotal) * BigInt.from(2) + q;
  return (n ~/ (BigInt.from(2) * q)).toInt();
}

/// Where the money of a return goes: the debt first, the rest back in cash. [balance] is the sale balance.
ReturnSplit returnPreview(int value, int balance) {
  final owed = balance < 0 ? 0 : balance;
  final debtDown = value < owed ? value : owed;
  final left = balance - value;
  return ReturnSplit(debtDown: debtDown, cashBack: value - debtDown, balanceAfter: left < 0 ? 0 : left);
}

/// True when this sale would push the customer past the credit limit.
bool overLimit(int owes, int balance, int? limit) => limit != null && balance > 0 && owes + balance > limit;

Json? _readMap(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) return null;
  try {
    return jsonDecode(raw) as Json;
  } catch (_) {
    return null;
  }
}

List<Json> _readList(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) return const [];
  try {
    return (jsonDecode(raw) as List<dynamic>).cast<Json>();
  } catch (_) {
    return const [];
  }
}

class CartState {
  const CartState({
    this.lines = const [],
    this.discount = 0,
    this.customer,
    this.paid,
    this.method = 'cash',
    this.note = '',
    this.held = const [],
  });

  final List<CartLine> lines;
  final int discount;
  final Customer? customer;

  /// Null means paid in full.
  final int? paid;
  final String method;
  final String note;
  final List<HeldCart> held;

  int get count => countOf(lines);
  int get subtotal => subtotalOf(lines);
  int get total => totalOf(subtotal, discount);
  int get paidAmount => paid ?? total;
  int get balance => balanceOf(total, paid);

  bool get stockProblem => lines.any((l) => l.qty > l.item.quantity);

  bool get canCheckout {
    if (lines.isEmpty || stockProblem) return false;
    if (balance < 0) return false;
    return balance == 0 || customer != null;
  }

  CartState copyWith({
    List<CartLine>? lines,
    int? discount,
    Customer? customer,
    bool clearCustomer = false,
    int? paid,
    bool clearPaid = false,
    String? method,
    String? note,
    List<HeldCart>? held,
  }) =>
      CartState(
        lines: lines ?? this.lines,
        discount: discount ?? this.discount,
        customer: clearCustomer ? null : (customer ?? this.customer),
        paid: clearPaid ? null : (paid ?? this.paid),
        method: method ?? this.method,
        note: note ?? this.note,
        held: held ?? this.held,
      );
}

/// Holds the cart. Read `ref.watch(cartProvider)`, change it with `ref.read(cartProvider.notifier)`.
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    final prefs = ref.read(sharedPrefsProvider);
    // A cart left on the phone belongs to the shop that just signed out.
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if ((previous?.isSignedIn ?? false) && !next.isSignedIn) {
        clearCartData(prefs);
        state = const CartState();
      }
    });
    final saved = _readMap(prefs, _cartKey);
    final held = [for (final h in _readList(prefs, _heldKey)) HeldCart.fromJson(h)];
    if (saved == null) return CartState(held: held);
    return CartState(
      lines: [for (final l in (saved['lines'] as List<dynamic>? ?? const [])) CartLine.fromJson(l as Json)],
      discount: saved['discount'] as int? ?? 0,
      customer: saved['customer'] is Map ? Customer.fromJson(saved['customer'] as Json) : null,
      paid: saved['paid'] as int?,
      method: saved['method'] as String? ?? 'cash',
      note: saved['note'] as String? ?? '',
      held: held,
    );
  }

  /// Adds one unit. Returns false when the item has no stock left or the cart is full.
  bool add(CartItem item) {
    final i = state.lines.indexWhere((l) => l.item.id == item.id);
    if (i == -1 && state.lines.length >= cartMaxLines) return false;
    final current = i == -1 ? 0 : state.lines[i].qty;
    if (current >= item.quantity) return false;
    final lines = [...state.lines];
    if (i == -1) {
      lines.add(CartLine(item: item, qty: 1));
    } else {
      lines[i] = CartLine(item: item, qty: current + 1);
    }
    state = state.copyWith(lines: lines);
    _saveCart();
    return true;
  }

  /// Sets the quantity. Never below 1 and never above the stock seen when the item was added.
  void setQty(int itemId, int qty) {
    final i = state.lines.indexWhere((l) => l.item.id == itemId);
    if (i == -1) return;
    final line = state.lines[i];
    final max = line.item.quantity < 1 ? 1 : line.item.quantity;
    final wanted = qty < 1 ? 1 : (qty > max ? max : qty);
    final lines = [...state.lines];
    lines[i] = CartLine(item: line.item, qty: wanted);
    state = state.copyWith(lines: lines);
    _saveCart();
  }

  void remove(int itemId) {
    state = state.copyWith(lines: state.lines.where((l) => l.item.id != itemId).toList());
    _saveCart();
  }

  void setDiscount(int paisa) {
    state = state.copyWith(discount: paisa < 0 ? 0 : paisa);
    _saveCart();
  }

  void setPaid(int? paisa) {
    state = paisa == null ? state.copyWith(clearPaid: true) : state.copyWith(paid: paisa);
    _saveCart();
  }

  void setCustomer(Customer? customer) {
    state = customer == null ? state.copyWith(clearCustomer: true) : state.copyWith(customer: customer);
    _saveCart();
  }

  void setMethod(String method) {
    state = state.copyWith(method: method);
    _saveCart();
  }

  void setNote(String text) {
    state = state.copyWith(note: text);
    _saveCart();
  }

  void clear() {
    state = CartState(held: state.held);
    _saveCart();
  }

  /// Parks the current cart in the held list and empties the cart. Null when the cart is empty.
  HeldCart? hold([String label = '']) {
    if (state.lines.isEmpty) return null;
    final typed = label.trim();
    final entry = HeldCart(
      id: newKey(),
      label: typed.isNotEmpty ? typed : (state.customer?.name ?? ''),
      at: DateTime.now().toUtc().toIso8601String(),
      lines: state.lines,
      discount: state.discount,
      customer: state.customer,
      paid: state.paid,
      method: state.method,
      note: state.note,
    );
    state = CartState(held: [entry, ...state.held]);
    _saveCart();
    _saveHeld();
    return entry;
  }

  /// Puts a held cart back in the cart. A cart with lines is held first, so nothing is lost.
  bool restore(String id) {
    final i = state.held.indexWhere((h) => h.id == id);
    if (i == -1) return false;
    final entry = state.held[i];
    if (state.lines.isNotEmpty) hold();
    state = CartState(
      lines: entry.lines,
      discount: entry.discount,
      customer: entry.customer,
      paid: entry.paid,
      method: entry.method,
      note: entry.note,
      held: state.held.where((h) => h.id != id).toList(),
    );
    _saveCart();
    _saveHeld();
    return true;
  }

  void discard(String id) {
    state = state.copyWith(held: state.held.where((h) => h.id != id).toList());
    _saveHeld();
  }

  void _saveCart() {
    final prefs = ref.read(sharedPrefsProvider);
    unawaited(
      prefs.setString(
        _cartKey,
        jsonEncode({
          'lines': [for (final l in state.lines) l.toJson()],
          'discount': state.discount,
          'customer': customerToJson(state.customer),
          'paid': state.paid,
          'method': state.method,
          'note': state.note,
        }),
      ),
    );
  }

  void _saveHeld() {
    final prefs = ref.read(sharedPrefsProvider);
    unawaited(prefs.setString(_heldKey, jsonEncode([for (final h in state.held) h.toJson()])));
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
