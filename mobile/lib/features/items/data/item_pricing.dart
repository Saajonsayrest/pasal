// Item price maths. Money is whole paisa and the rounding is done in integers, the same as the website.

/// The sell price without VAT, in paisa. [vatRate] is a percent such as 13.
/// Rounds half up. An item without VAT keeps its price.
int exVatPaisa(int sellPaisa, double vatRate, {bool vatApplies = true}) {
  if (!vatApplies) return sellPaisa;
  final rate = (vatRate * 100).round();
  final divisor = 10000 + rate;
  return (sellPaisa * 10000 + divisor ~/ 2) ~/ divisor;
}

/// Profit per piece: the price without VAT minus the buying price. Null when there is no buying price (staff).
int? profitPaisa({required int sellPaisa, required int? costPaisa, required double vatRate, required bool vatApplies}) {
  if (costPaisa == null) return null;
  return exVatPaisa(sellPaisa, vatRate, vatApplies: vatApplies) - costPaisa;
}

/// Margin in tenths of a percent (12.3% is 123), rounded half away from zero.
int marginTenths(int profitPaisa, int priceExVatPaisa) {
  if (priceExVatPaisa <= 0) return 0;
  final scaled = profitPaisa * 1000;
  final half = priceExVatPaisa ~/ 2;
  return scaled >= 0 ? (scaled + half) ~/ priceExVatPaisa : -((-scaled + half) ~/ priceExVatPaisa);
}

/// "15.3%" from tenths of a percent.
String marginText(int tenths) {
  final sign = tenths < 0 ? '-' : '';
  final abs = tenths.abs();
  return '$sign${abs ~/ 10}.${abs % 10}%';
}
