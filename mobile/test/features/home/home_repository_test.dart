import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/home/data/home_repository.dart';
import 'package:pasal_mobile/features/home/data/vat_period.dart';

import '../../helpers/fake_api.dart';
import 'home_fixtures.dart';

void main() {
  final today = todayAd();

  test('today sales read the daily report by hand (no from and to in the answer)', () async {
    final api = FakeApi()..on('GET', '/reports/daily', (q, b) => {'days': [], 'hours': [], 'total': 125000, 'bills': 3});
    final repo = HomeRepository(api);

    final sales = await repo.todaySales(today);

    expect(sales.total, 125000);
    expect(sales.bills, 3);
    expect(api.calls, ['GET /reports/daily']);
  });

  test('week days come back in the order the API sends them', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/reports/daily',
        (q, b) => {
          'days': [
            {'date': '2026-10-24', 'bills': 1, 'sales': 500},
            {'date': '2026-10-25', 'bills': 2, 'sales': 900},
          ],
          'hours': [],
          'total': 1400,
          'bills': 3,
        },
      );

    final days = await HomeRepository(api).dailyDays('2026-10-24', '2026-10-25');

    expect(days.map((d) => d.date), ['2026-10-24', '2026-10-25']);
    expect(days.last.sales, 900);
  });

  test('customers owe reads the summary of the list', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/customers',
        (q, b) => pagedJson([customerJson(1, 'Hari Thapa', 634000)], summary: {'owed_total': 634000, 'owing_customers': 2}),
      );

    final owed = await HomeRepository(api).customersOwe();

    expect(owed.owed, 634000);
    expect(owed.customers, 2);
    expect(api.calls, ['GET /customers']);
  });

  test('low stock count uses the total of the list, not its rows', () async {
    final asked = <Map<String, Object?>?>[];
    final api = FakeApi()
      ..on(
        'GET',
        '/items',
        (q, b) {
          asked.add(q);
          return pagedWithTotal([itemJson(id: 7, name: 'Rice 5kg', quantity: 2)], 4);
        },
      );

    expect(await HomeRepository(api).lowStockCount(), 4);
    expect(asked.single, {'low_stock': 1, 'per_page': 1});
  });

  test('vat preview asks for the period from the Nepali month and parses the payable amount', () async {
    final asked = <Map<String, Object?>?>[];
    final api = FakeApi()
      ..on(
        'GET',
        '/vat/preview',
        (q, b) {
          asked.add(q);
          return vatPreviewJson(payable: 520000);
        },
      );
    final period = nextVatPeriod();

    final preview = await HomeRepository(api).vatPreview(period);

    expect(preview.payable, 520000);
    expect(asked.single, {'from': period.from, 'to': period.to, 'opening_carry': 0});
  });

  test('staff bills: only the person\'s own bills that are not cancelled, minus returns', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/sales',
        (q, b) => pagedJson([
          saleJson(id: 1, total: 11300, soldBy: 'Asha Shrestha', customer: 'Sita Gurung', paid: 5000),
          saleJson(id: 2, total: 5000, returned: 1000, soldBy: 'Asha Shrestha'),
          saleJson(id: 3, total: 9000, soldBy: 'Asha Shrestha', cancelledAt: '2026-10-26T08:00:00+00:00'),
          saleJson(id: 4, total: 7000, soldBy: 'Ram Karki'),
        ]),
      );

    final mine = await HomeRepository(api).myToday(today, 'Asha Shrestha');

    expect(mine.bills, 2);
    expect(mine.total, 11300 + 5000 - 1000);
    expect(mine.recent.map((s) => s.id), [1, 2]);
  });

  test('notifications read the data list', () async {
    final api = FakeApi()
      ..on(
        'GET',
        '/notifications',
        (q, b) => {
          'data': [
            {'type': 'low_stock', 'title': 'Sugar is low on stock', 'body': 'Only 2 kg left', 'at': '2026-10-26T07:00:00+00:00'},
          ],
        },
      );

    final list = await HomeRepository(api).notifications();

    expect(list.single.type, 'low_stock');
    expect(list.single.title, 'Sugar is low on stock');
  });
}
