import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/features/home/data/vat_period.dart';

typedef TodaySales = ({int total, int bills});
typedef OwedToUs = ({int owed, int customers});
typedef MyToday = ({int total, int bills, List<Sale> recent});
typedef LowStock = ({int count, List<Item> items});

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

List<Json> _rows(Object? v) => (v as List<dynamic>? ?? const []).cast<Json>();

/// Numbers for the home screens. The daily report is read by hand because it has no `from` and `to`
/// in its answer (the shared [DailyReport] model needs them).
class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;

  Future<TodaySales> todaySales(String today) async {
    final json = await _api.get('/reports/daily', query: {'from': today, 'to': today});
    return (total: _int(json['total']), bills: _int(json['bills']));
  }

  Future<int> moneyInToday(String today) async {
    final json = await _api.get('/cash-book', query: {'from': today, 'to': today, 'per_page': 1});
    return _int(json['money_in']);
  }

  Future<OwedToUs> customersOwe() async {
    final page = await _api.page('/customers', Customer.fromJson, query: {'per_page': 1});
    return (owed: _int(page.summary['owed_total']), customers: _int(page.summary['owing_customers']));
  }

  Future<int> weOwe() async {
    final page = await _api.page('/suppliers', Supplier.fromJson, query: {'per_page': 1});
    return _int(page.summary['owed_total']);
  }

  Future<int> lowStockCount() async {
    final page = await _api.page('/items', Item.fromJson, query: {'low_stock': 1, 'per_page': 1});
    return page.meta.total;
  }

  Future<List<DayTotal>> dailyDays(String from, String to) async {
    final json = await _api.get('/reports/daily', query: {'from': from, 'to': to});
    return _rows(json['days']).map(DayTotal.fromJson).toList();
  }

  Future<Summary> monthSummary(String from, String to) async {
    return Summary.fromJson(await _api.get('/reports/summary', query: {'from': from, 'to': to}));
  }

  Future<VatPreview> vatPreview(VatPeriod period) async {
    return VatPreview.fromJson(await _api.get('/vat/preview', query: {'from': period.from, 'to': period.to, 'opening_carry': 0}));
  }

  Future<List<Sale>> recentSales() async {
    final page = await _api.page('/sales', Sale.fromJson, query: {'per_page': 3});
    return page.items;
  }

  /// Staff see only their own bills: the list is filtered by the name on the bill.
  Future<MyToday> myToday(String today, String name) async {
    final all = await _api.all('/sales', Sale.fromJson, query: {'from': today, 'to': today});
    final mine = all.where((s) => s.soldBy == name && s.cancelledAt == null).toList();
    final total = mine.fold<int>(0, (sum, s) => sum + s.total - s.returnedTotal);
    return (total: total, bills: mine.length, recent: mine.take(3).toList());
  }

  Future<List<Customer>> remindList() async {
    final page = await _api.page('/customers', Customer.fromJson, query: {'owes': 1, 'sort': 'oldest', 'per_page': 5});
    return page.items;
  }

  Future<LowStock> lowStockItems() async {
    final page = await _api.page('/items', Item.fromJson, query: {'low_stock': 1, 'per_page': 3});
    return (count: page.meta.total, items: page.items);
  }

  Future<List<AppNotification>> notifications() async {
    final json = await _api.get('/notifications');
    return _rows(json['data']).map(AppNotification.fromJson).toList();
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) => HomeRepository(ref.watch(apiClientProvider)));

final todaySalesProvider = FutureProvider.autoDispose<TodaySales>((ref) => ref.watch(homeRepositoryProvider).todaySales(todayAd()));

final moneyInTodayProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(homeRepositoryProvider).moneyInToday(todayAd()));

final customersOweProvider = FutureProvider.autoDispose<OwedToUs>((ref) => ref.watch(homeRepositoryProvider).customersOwe());

final weOweProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(homeRepositoryProvider).weOwe());

final lowStockCountProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(homeRepositoryProvider).lowStockCount());

/// The last 14 days, so the screen can compare the last 7 with the 7 before them.
final weekDaysProvider = FutureProvider.autoDispose<List<DayTotal>>((ref) {
  final today = todayAd();
  return ref.watch(homeRepositoryProvider).dailyDays(addDaysAd(today, -13), today);
});

/// Profit from the first day of this Nepali month until today.
final monthSummaryProvider = FutureProvider.autoDispose<Summary>((ref) {
  final now = todayBs();
  return ref.watch(homeRepositoryProvider).monthSummary(bsMonthRange(now.year, now.month).from, todayAd());
});

final vatPreviewProvider = FutureProvider.autoDispose<VatPreview>((ref) => ref.watch(homeRepositoryProvider).vatPreview(nextVatPeriod()));

final recentSalesProvider = FutureProvider.autoDispose<List<Sale>>((ref) => ref.watch(homeRepositoryProvider).recentSales());

final myTodayProvider = FutureProvider.autoDispose.family<MyToday, String>((ref, name) => ref.watch(homeRepositoryProvider).myToday(todayAd(), name));

final remindProvider = FutureProvider.autoDispose<List<Customer>>((ref) => ref.watch(homeRepositoryProvider).remindList());

final lowStockItemsProvider = FutureProvider.autoDispose<LowStock>((ref) => ref.watch(homeRepositoryProvider).lowStockItems());

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) => ref.watch(homeRepositoryProvider).notifications());
