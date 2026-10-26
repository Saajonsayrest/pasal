import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/providers.dart';

/// The cards of the owner's home screen. `wide` cards take the full width, the others share a row.
enum HomeCard {
  sales,
  cash,
  collect,
  owe,
  low,
  vat,
  week,
  profit;

  bool get wide => this == sales || this == week;
}

const _orderKey = 'pasal_home_order';

/// The saved order, plus any card added in a later version (added at the end).
List<HomeCard> _loadOrder(List<String>? saved) {
  final known = [
    for (final name in saved ?? const <String>[])
      for (final card in HomeCard.values)
        if (card.name == name) card,
  ];
  return [...{...known, ...HomeCard.values}];
}

class HomeOrderNotifier extends Notifier<List<HomeCard>> {
  @override
  List<HomeCard> build() => _loadOrder(ref.read(sharedPrefsProvider).getStringList(_orderKey));

  /// Moves the card at [index] up (-1) or down (1) by swapping it with its neighbour.
  void move(int index, int by) {
    final target = index + by;
    if (target < 0 || target >= state.length) return;
    final next = [...state];
    final moved = next[index];
    next[index] = next[target];
    next[target] = moved;
    state = next;
    ref.read(sharedPrefsProvider).setStringList(_orderKey, [for (final card in next) card.name]);
  }
}

final homeOrderProvider = NotifierProvider<HomeOrderNotifier, List<HomeCard>>(HomeOrderNotifier.new);

/// When the person last tapped "Mark all as read". Null means nothing was marked yet, so all is unread.
class NotificationSeenNotifier extends Notifier<DateTime?> {
  static const _key = 'pasal_notif_seen';

  @override
  DateTime? build() => DateTime.tryParse(ref.read(sharedPrefsProvider).getString(_key) ?? '');

  Future<void> markAllRead() async {
    final now = DateTime.now().toUtc();
    state = now;
    await ref.read(sharedPrefsProvider).setString(_key, now.toIso8601String());
  }
}

final notificationSeenProvider = NotifierProvider<NotificationSeenNotifier, DateTime?>(NotificationSeenNotifier.new);
