import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/features/money/data/cash_count_store.dart';
import 'package:pasal_mobile/features/money/data/money_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _expense(int id, String day, int amount, {String? category}) => {
      'id': id,
      'title': 'Expense $id',
      'category': category,
      'amount': amount,
      'spent_at': day,
    };

Map<String, dynamic> _entry(int id) => {
      'kind': 'payment_in',
      'id': id,
      'at': '2026-10-20T05:00:00+00:00',
      'amount': 100,
      'method': 'cash',
      'label': 'Customer $id',
      'balance': 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('expenses', () {
    test('keeps the range and stops reading once a page is older than it', () async {
      final api = FakeApi()
        ..on('GET', '/expenses', (q, b) {
          if (q!['page'] == 1) {
            return pagedJson(
              [_expense(1, '2026-10-20', 15000), _expense(2, '2026-11-02', 900), _expense(3, '2026-10-02', 3000)],
              page: 1,
              lastPage: 2,
            );
          }
          return pagedJson([_expense(4, '2026-09-28', 700)], page: 2, lastPage: 2);
        });

      final rows = await MoneyRepository(api).expenses((from: '2026-10-01', to: '2026-10-31'));

      expect(rows.map((e) => e.id), [1, 3]);
      expect(api.calls, ['GET /expenses', 'GET /expenses']);
    });

    test('addExpense sends the body and the key', () async {
      final api = FakeApi()
        ..on('POST', '/expenses', (q, b) => {'data': _expense(7, '2026-10-26', 150000, category: 'bills')});

      final saved = await MoneyRepository(api).addExpense(
        title: 'Electricity',
        category: 'bills',
        amount: 150000,
        spentAt: '2026-10-26',
        key: 'key-1',
      );

      expect(saved.id, 7);
      expect(api.bodies['POST /expenses']!.single, {
        'title': 'Electricity',
        'category': 'bills',
        'amount': 150000,
        'spent_at': '2026-10-26',
      });
      expect(api.keys['POST /expenses']!.single, 'key-1');
    });
  });

  test('cashBook reads every page of one day', () async {
    final api = FakeApi()
      ..on('GET', '/cash-book', (q, b) {
        final page = q!['page'] as int;
        final rows = page == 1 ? [for (var i = 1; i <= 100; i++) _entry(i)] : [for (var i = 101; i <= 150; i++) _entry(i)];
        return {
          'from': '2026-10-26',
          'to': '2026-10-26',
          'opening_balance': 1000,
          'money_in': 100,
          'money_out': 0,
          'closing_balance': 1100,
          'data': rows,
          'meta': {'current_page': page, 'per_page': 100, 'total': 150},
        };
      });

    final book = await MoneyRepository(api).cashBook('2026-10-26');

    expect(book.entries, hasLength(150));
    expect(book.entries.last.id, 150);
    expect(book.closingBalance, 1100);
    expect(api.calls, ['GET /cash-book', 'GET /cash-book']);
  });

  test('payments sends the filters and the page', () async {
    Query? seen;
    final api = FakeApi()
      ..on('GET', '/payments', (q, b) {
        seen = q;
        return pagedJson([]);
      });

    await MoneyRepository(api).payments((direction: 'in', method: null, from: '2026-10-01', to: '2026-10-31', page: 2));

    expect(seen!['direction'], 'in');
    expect(seen!['method'], isNull);
    expect(seen!['from'], '2026-10-01');
    expect(seen!['per_page'], 30);
    expect(seen!['page'], 2);
  });

  test('cash count store saves a day and lists them newest first', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = CashCountStore(prefs);

    await store.save(const CashCount(day: '2026-10-25', counted: 500000, expected: 510000));
    await store.save(const CashCount(day: '2026-10-26', counted: 640000, expected: 650000));

    expect(store.read('2026-10-26')!.diff, -10000);
    expect(prefs.getString('pasal_cash_count_2026-10-26'), '{"counted":640000,"expected":650000}');
    expect(store.all().map((c) => c.day), ['2026-10-26', '2026-10-25']);
    expect(store.read('2026-01-01'), isNull);
  });
}
