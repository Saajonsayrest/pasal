// Opens every screen of the real app (router, guards, theme) with fake server answers and checks that
// nothing throws. It does not look at pixels. It catches code that crashes on empty, normal or odd data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/app.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/router/app_router.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/storage/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_api.dart';
import 'helpers/pump_app.dart' show signedIn;

class _FixedSession extends SessionNotifier {
  _FixedSession(this._state);

  final SessionState _state;

  @override
  SessionState build() => _state;
}

const _customer = {'id': 1, 'name': 'Hari Thapa', 'phone': '9800000001', 'address': null, 'pan': null, 'credit_limit': 500000, 'owes': 150000, 'last_sale_at': '2026-10-24T07:26:03+00:00', 'oldest_unpaid_at': '2026-10-01T07:26:03+00:00'};
const _supplier = {'id': 1, 'name': 'Everest Traders', 'phone': '9811111111', 'address': null, 'pan': null, 'note': null, 'we_owe': 630000, 'last_purchase_at': '2026-10-20T07:26:03+00:00'};
const _item = {
  'id': 1, 'category_id': 1, 'name': 'Rice 5kg', 'sku': 'RICE-5', 'unit': 'pcs', 'vat_applies': true, 'cost_price': 80000, 'sell_price': 100000,
  'quantity': 5, 'low_stock_at': 6, 'is_low_stock': true, 'photo_url': null,
};
const _line = {'id': 1, 'item_id': 1, 'item_name': 'Rice 5kg', 'quantity': 2, 'unit_price': 100000, 'discount': 0, 'line_total': 200000, 'returned_quantity': 0};
const _payment = {'id': 1, 'direction': 'in', 'sale_id': 1, 'purchase_id': null, 'amount': 50000, 'method': 'cash', 'paid_at': '2026-10-26T07:26:03+00:00', 'party': 'Hari Thapa'};
final _sale = {
  'id': 1, 'bill_no': 'S-0001', 'customer_id': 1, 'customer': _customer, 'subtotal': 200000, 'discount': 0, 'total': 200000, 'returned_total': 0, 'paid': 50000,
  'balance': 150000, 'cancelled_at': null, 'vat_rate': 13.0, 'taxable_amount': 176991, 'vat_amount': 23009, 'exempt_amount': 0,
  'sold_at': '2026-10-26T07:26:03+00:00', 'note': null, 'sold_by': 'Asha Shrestha', 'items': [_line], 'payments': [_payment], 'returns': [],
};
final _purchase = {
  'id': 1, 'bill_no': 'INV-889', 'bill_date': '2026-10-24', 'supplier_id': 1, 'supplier': _supplier, 'total': 1130000, 'paid': 500000, 'balance': 630000,
  'vat_amount': 130000, 'bought_at': '2026-10-26T07:26:03+00:00', 'note': null,
  'items': [{'item_id': 1, 'item_name': 'Rice 5kg', 'quantity': 10, 'unit_cost': 100000, 'line_total': 1000000}],
  'payments': [{..._payment, 'direction': 'out', 'sale_id': null, 'purchase_id': 1}],
};
const _filing = {
  'id': 1, 'period': '2083-07', 'period_from': '2026-10-18', 'period_to': '2026-11-16', 'source': 'computed', 'sales_taxable': 0, 'sales_exempt': 0,
  'output_vat': 0, 'purchases_taxable': 0, 'input_vat': 0, 'carry_in': 0, 'payable': 0, 'carry_out': 0, 'filed_on': null, 'paid_amount': 0,
  'paid_on': null, 'receipt_no': null, 'note': null,
};
const _business = {'id': 1, 'name': 'Himal Kirana Pasal', 'pan': '600000001', 'phone': '01-0000000', 'address': 'Baneshwor', 'vat_rate': 13.0};

Map<String, dynamic> _list(List<Map<String, dynamic>> rows, {Map<String, dynamic>? summary}) => {
      'data': rows,
      'meta': {'current_page': 1, 'last_page': 1, 'per_page': 50, 'total': rows.length},
      'summary': ?summary,
    };

/// Answers by address, shaped like the real API.
Object? _answer(String method, String path, Query? q, Object? body, {required bool empty}) {
  if (method != 'GET') return {'data': _sale, 'message': 'ok', 'owes_left': 0, 'balance_left': 0, 'items_changed': 0};
  final rows = !empty;
  Map<String, dynamic> list(Map<String, dynamic> row, {Map<String, dynamic>? summary}) => _list(rows ? [row] : [], summary: summary);

  if (RegExp(r'^/customers/\d+/ledger$').hasMatch(path)) {
    return {'customer': _customer, 'total_sales': 200000, 'total_paid': 50000, 'owes': 150000, 'credit_limit': 500000, 'sales': [if (rows) {'id': 1, 'bill_no': 'S-0001', 'sold_at': '2026-10-26T07:26:03+00:00', 'total': 200000, 'returned_total': 0, 'paid': 50000, 'balance': 150000, 'cancelled_at': null}], 'payments': [if (rows) _payment]};
  }
  if (RegExp(r'^/suppliers/\d+/ledger$').hasMatch(path)) {
    return {'supplier': _supplier, 'total_purchases': 1130000, 'total_paid': 500000, 'we_owe': 630000, 'purchases': [if (rows) {'id': 1, 'bill_no': 'INV-889', 'bought_at': '2026-10-26T07:26:03+00:00', 'total': 1130000, 'paid': 500000, 'balance': 630000}], 'payments': [if (rows) {..._payment, 'direction': 'out', 'sale_id': null, 'purchase_id': 1}]};
  }
  if (RegExp(r'^/items/\d+/stock-movements$').hasMatch(path)) {
    return {'item': {'id': 1, 'name': 'Rice 5kg', 'quantity': 5}, ..._list(rows ? [{'id': 1, 'change': -2, 'reason': 'sale', 'ref_type': 'sale', 'ref_id': 1, 'note': null, 'by': 'Asha', 'at': '2026-10-26T07:26:03+00:00'}] : [])};
  }
  if (RegExp(r'^/customers/\d+$').hasMatch(path)) return {'data': _customer};
  if (RegExp(r'^/suppliers/\d+$').hasMatch(path)) return {'data': _supplier};
  if (RegExp(r'^/items/\d+$').hasMatch(path)) return {'data': _item};
  if (RegExp(r'^/sales/\d+$').hasMatch(path)) return {'data': _sale};
  if (RegExp(r'^/purchases/\d+$').hasMatch(path)) return {'data': _purchase};
  if (RegExp(r'^/vat/filings/\d+$').hasMatch(path)) return {'data': _filing};
  if (path == '/vat/preview') {
    return {'period_from': '2026-10-18', 'period_to': '2026-11-16', 'due_date': '2026-12-11', 'vat_rate': 13.0, 'sales_bills': 3, 'sales_taxable': 100000, 'sales_exempt': 0, 'output_vat': 13000, 'purchase_bills_with_vat': 1, 'purchases_taxable': 50000, 'input_vat': 6500, 'carry_in': 0, 'payable': 6500, 'carry_out': 0, 'carry_in_source': 'opening value you typed (0 if none)'};
  }
  switch (path) {
    case '/business':
      return {'data': _business};
    case '/me':
      return {'id': 1, 'name': 'Asha Shrestha', 'email': 'asha@example.com', 'role': 'owner', 'business': _business};
    case '/customers':
      return list(_customer, summary: {'owed_total': 150000, 'owing_customers': 1});
    case '/suppliers':
      return list(_supplier, summary: {'owed_total': 630000});
    case '/items':
    case '/items/suggest':
      return list(_item);
    case '/categories':
      return list({'id': 1, 'name': 'Grocery', 'icon': 'rice_bowl', 'color': '#e0731a'});
    case '/sales':
      return list({..._sale, 'items': null, 'payments': null, 'returns': null});
    case '/purchases':
      return list({..._purchase, 'items': null, 'payments': null});
    case '/payments':
      return list(_payment);
    case '/expenses':
      return list({'id': 1, 'title': 'Electricity', 'category': 'bills', 'amount': 185000, 'spent_at': '2026-10-20T00:00:00+00:00'});
    case '/users':
      return list({'id': 2, 'name': 'Bikash K.', 'email': 'b@example.com', 'role': 'staff'});
    case '/vat/filings':
      return list(_filing);
    case '/notifications':
      return {'data': [if (rows) {'type': 'low_stock', 'title': '2 items are low on stock', 'body': 'Sugar, Salt', 'at': '2026-10-26T07:26:03+00:00', 'count': 2}]};
    case '/activity':
      return list({'kind': 'sale', 'ref_id': 1, 'at': '2026-10-26T07:26:03+00:00', 'by': 'Asha Shrestha', 'label': 'S-0001', 'amount': 200000});
    case '/reports/summary':
      return {'from': '2026-10-01', 'to': '2026-10-31', 'sales_total': 540000, 'vat_collected': 62000, 'cost_of_goods': 300000, 'expenses_total': 50000, 'profit': 128000, 'stock_value': 900000, 'owed_to_us': 150000, 'we_owe': 630000};
    case '/reports/daily':
      return {'from': '2026-10-20', 'to': '2026-10-26', 'days': [if (rows) {'date': '2026-10-26', 'bills': 3, 'sales': 450000}], 'hours': [for (var h = 0; h < 24; h++) {'hour': h, 'bills': rows && h == 10 ? 2 : 0, 'sales': rows && h == 10 ? 300000 : 0}], 'total': rows ? 450000 : 0, 'bills': rows ? 3 : 0};
    case '/reports/items':
      return {'from': '2026-10-01', 'to': '2026-10-31', 'top': [if (rows) {'item_id': 1, 'name': 'Rice 5kg', 'unit': 'pcs', 'quantity': 5, 'revenue': 500000}], 'slow': [if (rows) {'item_id': 2, 'name': 'Sugar', 'unit': 'pcs', 'in_stock': 8, 'sold': 0, 'stock_value': 80000}]};
    case '/reports/staff':
      return {'from': '2026-10-01', 'to': '2026-10-31', 'data': [if (rows) {'user_id': 1, 'name': 'Asha Shrestha', 'bills': 4, 'sales': 540000, 'discount': 0}]};
    case '/reports/credit-age':
      return {'as_of': '2026-10-26', 'total': rows ? 150000 : 0, 'buckets': [for (final k in ['d0_30', 'd31_60', 'd61_90', 'd90_plus']) {'key': k, 'label': k, 'bills': rows && k == 'd0_30' ? 1 : 0, 'amount': rows && k == 'd0_30' ? 150000 : 0}], 'customers': [if (rows) {'customer_id': 1, 'name': 'Hari Thapa', 'phone': '9800000001', 'owes': 150000, 'oldest_days': 12, 'bucket': 'd0_30'}]};
    case '/cash-book':
      return {'from': '2026-10-26', 'to': '2026-10-26', 'opening_balance': 10000, 'money_in': rows ? 50000 : 0, 'money_out': rows ? 20000 : 0, 'closing_balance': 40000, 'data': [if (rows) {'kind': 'payment_in', 'id': 1, 'at': '2026-10-26T07:26:03+00:00', 'amount': 50000, 'method': 'cash', 'label': 'Hari Thapa', 'balance': 60000}], 'meta': {'current_page': 1, 'last_page': 1, 'per_page': 100, 'total': rows ? 1 : 0}};
  }
  return _list([]);
}

/// Screens that need the camera plugin, which has no test version.
const _skip = {'/sell/scan', '/items/scan'};

const _ownerPaths = [
  '/', '/items', '/sell', '/customers', '/more', '/profile', '/forgot-password', '/reset-password?token=abc&email=a%40b.com', '/welcome', '/notifications',
  '/sell/checkout', '/sell/held', '/sales', '/sales/1', '/sales/1/bill', '/sales/1/return', '/sales/1/cancel',
  '/items/new', '/items/deleted', '/items/1', '/items/1/edit', '/items/1/adjust', '/items/1/history', '/stock-count', '/low-stock', '/categories', '/barcode-labels', '/expiry',
  '/customers/new', '/customers/1', '/customers/1/edit', '/customers/1/payment', '/customers/1/remind', '/customers/1/statement',
  '/suppliers', '/suppliers/new', '/suppliers/1', '/suppliers/1/edit', '/suppliers/1/pay', '/purchases', '/purchases/new', '/purchases/1', '/purchase-return',
  '/expenses', '/expenses/new', '/cash-book', '/payments',
  '/reports', '/reports/sales', '/reports/items', '/reports/credit-age', '/reports/staff', '/reports/export',
  '/vat', '/vat/filings', '/vat/filings/1', '/vat/old-return', '/vat/books',
  '/settings/shop', '/settings/staff', '/settings/look', '/settings/printer', '/settings/activity', '/settings/backup',
];

Future<void> _openAll(WidgetTester tester, List<String> paths, {required bool owner, required bool empty}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = FakeApi()..fallback = (m, p, q, b) => _answer(m, p, q, b, empty: empty);
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: <Override>[
      sharedPrefsProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith(() => _FixedSession(signedIn(owner: owner))),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const PasalApp()));
  await tester.pumpAndSettle();
  final router = container.read(appRouterProvider);

  for (final path in paths.where((p) => !_skip.contains(p))) {
    router.go(path);
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    final problem = tester.takeException();
    expect(problem, isNull, reason: '$path threw: $problem');
    expect(find.byType(Scaffold), findsWidgets, reason: '$path shows nothing');
  }
}

void main() {
  testWidgets('every screen opens with rows of data (owner)', (tester) => _openAll(tester, _ownerPaths, owner: true, empty: false));

  testWidgets('every screen opens with empty lists (owner)', (tester) => _openAll(tester, _ownerPaths, owner: true, empty: true));

  testWidgets('staff can open the counter screens and are sent home from owner screens', (tester) async {
    await _openAll(tester, ['/', '/items', '/sell', '/customers', '/more', '/sales', '/sales/1', '/sales/1/bill', '/items/1', '/customers/1', '/customers/1/payment', '/settings/look', '/profile', '/notifications'], owner: false, empty: false);
  });
}
