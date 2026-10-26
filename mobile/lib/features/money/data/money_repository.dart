import 'dart:math' show min;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/utils/bs.dart';

/// First and last AD day, both included ("2026-10-01" to "2026-10-31").
typedef DayRange = ({String from, String to});

/// One page of the payments list. A record has equality, so it can be a provider family key.
typedef PaymentQuery = ({String? direction, String? method, String from, String to, int page});

/// The AD day ("2026-10-26") of an ISO time stamp or of a plain date.
String adDayOf(String stamp) => stamp.length > 10 ? adOfStamp(stamp) : stamp.substring(0, 10);

/// Talks to /expenses, /cash-book and /payments. Screens go through the providers below.
class MoneyRepository {
  MoneyRepository(this._api);

  final ApiClient _api;

  /// Expenses from [range], newest first. The API has no date filter for expenses, so pages are
  /// read until the rows are older than the range.
  Future<List<Expense>> expenses(DayRange range) async {
    final rows = <Expense>[];
    for (var page = 1; page <= 200; page++) {
      final res = await _api.page('/expenses', Expense.fromJson, query: {'per_page': 50, 'page': page});
      rows.addAll(res.items);
      if (res.items.isEmpty || adDayOf(res.items.last.spentAt).compareTo(range.from) < 0) break;
      if (!res.meta.hasMore) break;
    }
    return rows.where((e) {
      final day = adDayOf(e.spentAt);
      return day.compareTo(range.from) >= 0 && day.compareTo(range.to) <= 0;
    }).toList();
  }

  /// Saves one expense. Pass the screen's [key] so a retry of the same tap cannot save it twice.
  Future<Expense> addExpense({
    required String title,
    required String? category,
    required int amount,
    required String spentAt,
    required String key,
  }) async {
    final json = await _api.post(
      '/expenses',
      body: {'title': title, 'category': category, 'amount': amount, 'spent_at': spentAt},
      key: key,
    );
    return Expense.fromJson(json['data'] as Json);
  }

  /// Every entry of one day. The API sends 100 rows a page, so the other pages are read too.
  Future<CashBook> cashBook(String day) async {
    final first = CashBook.fromJson(await _api.get('/cash-book', query: {'from': day, 'to': day, 'per_page': 100, 'page': 1}));
    final entries = [...first.entries];
    final last = min(200, (first.total + 99) ~/ 100);
    for (var page = 2; page <= last; page++) {
      final next = CashBook.fromJson(await _api.get('/cash-book', query: {'from': day, 'to': day, 'per_page': 100, 'page': page}));
      entries.addAll(next.entries);
    }
    return CashBook(
      from: first.from,
      to: first.to,
      openingBalance: first.openingBalance,
      moneyIn: first.moneyIn,
      moneyOut: first.moneyOut,
      closingBalance: first.closingBalance,
      entries: entries,
      total: first.total,
    );
  }

  /// One page of payments, newest first.
  Future<Paged<Payment>> payments(PaymentQuery q) => _api.page(
        '/payments',
        Payment.fromJson,
        query: {
          'direction': q.direction,
          'method': q.method,
          'from': q.from,
          'to': q.to,
          'per_page': 30,
          'page': q.page,
        },
      );
}

final moneyRepositoryProvider = Provider<MoneyRepository>((ref) => MoneyRepository(ref.watch(apiClientProvider)));

final expensesProvider = FutureProvider.autoDispose.family<List<Expense>, DayRange>(
  (ref, range) => ref.watch(moneyRepositoryProvider).expenses(range),
);

final cashBookProvider = FutureProvider.autoDispose.family<CashBook, String>(
  (ref, day) => ref.watch(moneyRepositoryProvider).cashBook(day),
);

final paymentsProvider = FutureProvider.autoDispose.family<Paged<Payment>, PaymentQuery>(
  (ref, q) => ref.watch(moneyRepositoryProvider).payments(q),
);
