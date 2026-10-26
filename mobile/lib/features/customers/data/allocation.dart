import 'package:pasal_mobile/core/models/models.dart';

/// A bill that still has money to pay.
class OpenBill {
  const OpenBill({required this.id, required this.billNo, required this.soldAt, required this.balance});

  factory OpenBill.fromSale(LedgerSale sale) => OpenBill(id: sale.id, billNo: sale.billNo, soldAt: sale.soldAt, balance: sale.balance);

  final int id;
  final String? billNo;
  final String soldAt;

  /// Paisa still to pay on this bill.
  final int balance;
}

/// What one payment puts on one bill.
class BillShare {
  const BillShare({required this.bill, required this.pays, required this.paidOff});

  final OpenBill bill;

  /// Paisa, always more than 0.
  final int pays;
  final bool paidOff;
}

class Allocation {
  const Allocation({required this.allocations, required this.leftover});

  final List<BillShare> allocations;

  /// Paisa left over after every open bill is paid. More than 0 only when the amount is too big.
  final int leftover;
}

/// Spreads a customer payment over open bills, oldest first. Mirrors the server so the take payment
/// screen can show a preview. The server still decides the real result.
Allocation allocateOldestFirst(List<OpenBill> bills, int amount) {
  final open = bills.where((b) => b.balance > 0).toList()
    ..sort((a, b) {
      final byDate = DateTime.parse(a.soldAt).compareTo(DateTime.parse(b.soldAt));
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  var left = amount < 0 ? 0 : amount;
  final shares = <BillShare>[];
  for (final bill in open) {
    if (left == 0) break;
    final pays = left < bill.balance ? left : bill.balance;
    left -= pays;
    shares.add(BillShare(bill: bill, pays: pays, paidOff: pays == bill.balance));
  }
  return Allocation(allocations: shares, leftover: left);
}
