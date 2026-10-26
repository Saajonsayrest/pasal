import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/features/home/data/home_prefs.dart';
import 'package:pasal_mobile/features/home/presentation/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the home cards start in the default order', () async {
    final c = await _container({});
    expect(c.read(homeOrderProvider), HomeCard.values);
  });

  test('a saved order wins, and cards missing from it are added at the end', () async {
    final c = await _container({
      'pasal_home_order': ['profit', 'sales', 'unknown_card'],
    });
    final order = c.read(homeOrderProvider);
    expect(order.take(2), [HomeCard.profit, HomeCard.sales]);
    expect(order.length, HomeCard.values.length);
    expect(order.toSet(), HomeCard.values.toSet());
  });

  test('moving a card swaps it with its neighbour and saves the order', () async {
    final c = await _container({});
    c.read(homeOrderProvider.notifier).move(0, 1);

    expect(c.read(homeOrderProvider).take(2), [HomeCard.cash, HomeCard.sales]);
    final saved = c.read(sharedPrefsProvider).getStringList('pasal_home_order');
    expect(saved?.take(2), ['cash', 'sales']);
  });

  test('moving the first card up does nothing', () async {
    final c = await _container({});
    c.read(homeOrderProvider.notifier).move(0, -1);
    expect(c.read(homeOrderProvider), HomeCard.values);
  });

  test('the wide cards are the sales hero and the week chart', () {
    expect(HomeCard.values.where((c) => c.wide).toList(), [HomeCard.sales, HomeCard.week]);
  });

  test('notifications are unread until mark all as read is pressed', () async {
    final c = await _container({});
    expect(c.read(notificationSeenProvider), isNull);

    await c.read(notificationSeenProvider.notifier).markAllRead();

    expect(c.read(notificationSeenProvider), isNotNull);
    expect(c.read(sharedPrefsProvider).getString('pasal_notif_seen'), isNotNull);
  });

  test('the notification filter chips show the right kinds', () {
    expect(noticeMatchesFilter('all', 'vat_due'), isTrue);
    expect(noticeMatchesFilter('stock', 'low_stock'), isTrue);
    expect(noticeMatchesFilter('stock', 'credit_overdue'), isFalse);
    expect(noticeMatchesFilter('money', 'credit_overdue'), isTrue);
    expect(noticeMatchesFilter('vat', 'vat_unfiled'), isTrue);
    expect(noticeMatchesFilter('vat', 'vat_due'), isTrue);
    expect(noticeMatchesFilter('vat', 'staff_added'), isFalse);
  });
}
