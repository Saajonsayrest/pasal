import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/utils/bs.dart';

/// Stock changes that come from a bill. They count as sold.
const saleMovementReasons = {'sale', 'sale_return', 'sale_cancel'};

/// Units sold in the last 30 days, and the same split into five weeks (the newest week is last).
class SalesWindow {
  const SalesWindow({required this.sold, required this.weeks});

  final int sold;
  final List<int> weeks;
}

/// Works out the last 30 days from the stock history, the same way the website does (shop days, bills only).
SalesWindow salesWindow(List<StockMovement> moves) {
  var sold = 0;
  final weeks = List<int>.filled(5, 0);
  for (final m in moves) {
    if (!saleMovementReasons.contains(m.reason)) continue;
    final daysAgo = -daysUntil(adOfStamp(m.at));
    if (daysAgo > 29) continue;
    sold -= m.change;
    final week = daysAgo <= 0 ? 0 : daysAgo ~/ 6;
    weeks[4 - week] -= m.change;
  }
  return SalesWindow(sold: sold, weeks: [for (final w in weeks) w < 0 ? 0 : w]);
}
