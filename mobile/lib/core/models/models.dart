/// Shapes of the PASAL API (docs/api-reference.md). Money is whole paisa. Dates are ISO strings.
/// Hand written on purpose (no code generation): small, readable and easy to test.
/// Matches web/src/lib/types.ts.
library;

typedef Json = Map<String, dynamic>;

int _i(Object? v, [int fallback = 0]) => v == null ? fallback : (v as num).toInt();
int? _in(Object? v) => v == null ? null : (v as num).toInt();
String? _sn(Object? v) => v as String?;
bool _b(Object? v, [bool fallback = false]) => v == null ? fallback : v as bool;
List<Json> _list(Object? v) => (v as List<dynamic>? ?? const []).cast<Json>();

class Business {
  const Business({required this.id, required this.name, this.pan, this.phone, this.address, this.vatRate = 13});

  factory Business.fromJson(Json j) => Business(
        id: _i(j['id']),
        name: j['name'] as String,
        pan: _sn(j['pan']),
        phone: _sn(j['phone']),
        address: _sn(j['address']),
        vatRate: (j['vat_rate'] as num?)?.toDouble() ?? 13,
      );

  final int id;
  final String name;
  final String? pan;
  final String? phone;
  final String? address;
  final double vatRate;
}

class AppUser {
  const AppUser({required this.id, required this.name, required this.email, required this.role, this.business});

  factory AppUser.fromJson(Json j) => AppUser(
        id: _i(j['id']),
        name: j['name'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        business: j['business'] == null ? null : Business.fromJson(j['business'] as Json),
      );

  final int id;
  final String name;
  final String email;

  /// `owner` or `staff`.
  final String role;
  final Business? business;

  bool get isOwner => role == 'owner';
}

class Category {
  const Category({required this.id, required this.name, this.icon, this.color});

  factory Category.fromJson(Json j) => Category(
        id: _i(j['id']),
        name: j['name'] as String,
        icon: _sn(j['icon']),
        color: _sn(j['color']),
      );

  final int id;
  final String name;

  /// A Material Symbols name such as `egg`.
  final String? icon;

  /// `#rrggbb`.
  final String? color;
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.unit,
    required this.vatApplies,
    required this.sellPrice,
    required this.quantity,
    required this.lowStockAt,
    required this.isLowStock,
    this.categoryId,
    this.sku,
    this.costPrice,
    this.photoUrl,
  });

  factory Item.fromJson(Json j) => Item(
        id: _i(j['id']),
        categoryId: _in(j['category_id']),
        name: j['name'] as String,
        sku: _sn(j['sku']),
        unit: (j['unit'] as String?) ?? 'pcs',
        vatApplies: _b(j['vat_applies'], true),
        costPrice: _in(j['cost_price']),
        sellPrice: _i(j['sell_price']),
        quantity: _i(j['quantity']),
        lowStockAt: _i(j['low_stock_at']),
        isLowStock: _b(j['is_low_stock']),
        photoUrl: _sn(j['photo_url']),
      );

  final int id;
  final int? categoryId;
  final String name;
  final String? sku;
  final String unit;
  final bool vatApplies;

  /// Null for staff.
  final int? costPrice;

  /// Includes VAT.
  final int sellPrice;
  final int quantity;
  final int lowStockAt;
  final bool isLowStock;
  final String? photoUrl;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.pan,
    this.creditLimit,
    this.owes,
    this.lastSaleAt,
    this.oldestUnpaidAt,
  });

  factory Customer.fromJson(Json j) => Customer(
        id: _i(j['id']),
        name: j['name'] as String,
        phone: _sn(j['phone']),
        address: _sn(j['address']),
        pan: _sn(j['pan']),
        creditLimit: _in(j['credit_limit']),
        owes: _in(j['owes']),
        lastSaleAt: _sn(j['last_sale_at']),
        oldestUnpaidAt: _sn(j['oldest_unpaid_at']),
      );

  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? pan;

  /// Null = no limit. 0 = cash only.
  final int? creditLimit;

  /// Paisa still to collect. Only on GET /customers and GET /customers/{id}.
  final int? owes;
  final String? lastSaleAt;
  final String? oldestUnpaidAt;
}

class Supplier {
  const Supplier({required this.id, required this.name, this.phone, this.address, this.pan, this.note, this.weOwe, this.lastPurchaseAt});

  factory Supplier.fromJson(Json j) => Supplier(
        id: _i(j['id']),
        name: j['name'] as String,
        phone: _sn(j['phone']),
        address: _sn(j['address']),
        pan: _sn(j['pan']),
        note: _sn(j['note']),
        weOwe: _in(j['we_owe']),
        lastPurchaseAt: _sn(j['last_purchase_at']),
      );

  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? pan;
  final String? note;

  /// Paisa still to pay. Only on GET /suppliers and GET /suppliers/{id}.
  final int? weOwe;
  final String? lastPurchaseAt;
}

class SaleLine {
  const SaleLine({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
    required this.returnedQuantity,
  });

  factory SaleLine.fromJson(Json j) => SaleLine(
        id: _i(j['id']),
        itemId: _i(j['item_id']),
        itemName: (j['item_name'] as String?) ?? '?',
        quantity: _i(j['quantity']),
        unitPrice: _i(j['unit_price']),
        discount: _i(j['discount']),
        lineTotal: _i(j['line_total']),
        returnedQuantity: _i(j['returned_quantity']),
      );

  final int id;
  final int itemId;
  final String itemName;
  final int quantity;
  final int unitPrice;
  final int discount;
  final int lineTotal;
  final int returnedQuantity;
}

class Payment {
  const Payment({
    required this.id,
    required this.direction,
    required this.amount,
    required this.method,
    required this.paidAt,
    this.saleId,
    this.purchaseId,
    this.party,
  });

  factory Payment.fromJson(Json j) => Payment(
        id: _i(j['id']),
        direction: j['direction'] as String,
        saleId: _in(j['sale_id']),
        purchaseId: _in(j['purchase_id']),
        amount: _i(j['amount']),
        method: (j['method'] as String?) ?? 'cash',
        paidAt: j['paid_at'] as String,
        party: _sn(j['party']),
      );

  final int id;

  /// `in`, `out` or `refund`.
  final String direction;
  final int? saleId;
  final int? purchaseId;
  final int amount;
  final String method;
  final String paidAt;
  final String? party;
}

class SaleReturn {
  const SaleReturn({
    required this.id,
    required this.saleId,
    required this.kind,
    required this.returnedAt,
    required this.total,
    required this.vatAmount,
    required this.refunded,
    required this.restocked,
    this.note,
  });

  factory SaleReturn.fromJson(Json j) => SaleReturn(
        id: _i(j['id']),
        saleId: _i(j['sale_id']),
        kind: j['kind'] as String,
        returnedAt: j['returned_at'] as String,
        total: _i(j['total']),
        vatAmount: _i(j['vat_amount']),
        refunded: _i(j['refunded']),
        restocked: _b(j['restocked'], true),
        note: _sn(j['note']),
      );

  final int id;
  final int saleId;

  /// `return` or `cancel`.
  final String kind;
  final String returnedAt;
  final int total;
  final int vatAmount;
  final int refunded;
  final bool restocked;
  final String? note;
}

class Sale {
  const Sale({
    required this.id,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.returnedTotal,
    required this.paid,
    required this.balance,
    required this.vatRate,
    required this.taxableAmount,
    required this.vatAmount,
    required this.exemptAmount,
    required this.soldAt,
    this.billNo,
    this.customerId,
    this.customer,
    this.cancelledAt,
    this.note,
    this.soldBy,
    this.items,
    this.payments,
    this.returns,
  });

  factory Sale.fromJson(Json j) => Sale(
        id: _i(j['id']),
        billNo: _sn(j['bill_no']),
        customerId: _in(j['customer_id']),
        customer: j['customer'] == null ? null : Customer.fromJson(j['customer'] as Json),
        subtotal: _i(j['subtotal']),
        discount: _i(j['discount']),
        total: _i(j['total']),
        returnedTotal: _i(j['returned_total']),
        paid: _i(j['paid']),
        balance: _i(j['balance']),
        cancelledAt: _sn(j['cancelled_at']),
        vatRate: (j['vat_rate'] as num?)?.toDouble() ?? 0,
        taxableAmount: _i(j['taxable_amount']),
        vatAmount: _i(j['vat_amount']),
        exemptAmount: _i(j['exempt_amount']),
        soldAt: j['sold_at'] as String,
        note: _sn(j['note']),
        soldBy: _sn(j['sold_by']),
        items: j['items'] == null ? null : _list(j['items']).map(SaleLine.fromJson).toList(),
        payments: j['payments'] == null ? null : _list(j['payments']).map(Payment.fromJson).toList(),
        returns: j['returns'] == null ? null : _list(j['returns']).map(SaleReturn.fromJson).toList(),
      );

  final int id;
  final String? billNo;
  final int? customerId;
  final Customer? customer;
  final int subtotal;
  final int discount;
  final int total;
  final int returnedTotal;
  final int paid;
  final int balance;
  final String? cancelledAt;
  final double vatRate;
  final int taxableAmount;
  final int vatAmount;
  final int exemptAmount;
  final String soldAt;
  final String? note;
  final String? soldBy;
  final List<SaleLine>? items;
  final List<Payment>? payments;
  final List<SaleReturn>? returns;

  bool get isCancelled => cancelledAt != null;
}

class PurchaseLine {
  const PurchaseLine({required this.itemId, required this.itemName, required this.quantity, required this.unitCost, required this.lineTotal});

  factory PurchaseLine.fromJson(Json j) => PurchaseLine(
        itemId: _i(j['item_id']),
        itemName: (j['item_name'] as String?) ?? '?',
        quantity: _i(j['quantity']),
        unitCost: _i(j['unit_cost']),
        lineTotal: _i(j['line_total']),
      );

  final int itemId;
  final String itemName;
  final int quantity;
  final int unitCost;
  final int lineTotal;
}

class Purchase {
  const Purchase({
    required this.id,
    required this.supplierId,
    required this.total,
    required this.paid,
    required this.balance,
    required this.vatAmount,
    required this.boughtAt,
    this.billNo,
    this.billDate,
    this.supplier,
    this.note,
    this.items,
    this.payments,
  });

  factory Purchase.fromJson(Json j) => Purchase(
        id: _i(j['id']),
        billNo: _sn(j['bill_no']),
        billDate: _sn(j['bill_date']),
        supplierId: _i(j['supplier_id']),
        supplier: j['supplier'] == null ? null : Supplier.fromJson(j['supplier'] as Json),
        total: _i(j['total']),
        paid: _i(j['paid']),
        balance: _i(j['balance']),
        vatAmount: _i(j['vat_amount']),
        boughtAt: j['bought_at'] as String,
        note: _sn(j['note']),
        items: j['items'] == null ? null : _list(j['items']).map(PurchaseLine.fromJson).toList(),
        payments: j['payments'] == null ? null : _list(j['payments']).map(Payment.fromJson).toList(),
      );

  final int id;
  final String? billNo;
  final String? billDate;
  final int supplierId;
  final Supplier? supplier;
  final int total;
  final int paid;
  final int balance;
  final int vatAmount;
  final String boughtAt;
  final String? note;
  final List<PurchaseLine>? items;
  final List<Payment>? payments;
}

class Expense {
  const Expense({required this.id, required this.title, required this.amount, required this.spentAt, this.category});

  factory Expense.fromJson(Json j) => Expense(
        id: _i(j['id']),
        title: j['title'] as String,
        category: _sn(j['category']),
        amount: _i(j['amount']),
        spentAt: j['spent_at'] as String,
      );

  final int id;
  final String title;
  final String? category;
  final int amount;
  final String spentAt;
}

class VatPreview {
  const VatPreview({
    required this.periodFrom,
    required this.periodTo,
    required this.dueDate,
    required this.vatRate,
    required this.salesBills,
    required this.salesTaxable,
    required this.salesExempt,
    required this.outputVat,
    required this.purchaseBillsWithVat,
    required this.purchasesTaxable,
    required this.inputVat,
    required this.carryIn,
    required this.payable,
    required this.carryOut,
    required this.carryInSource,
  });

  factory VatPreview.fromJson(Json j) => VatPreview(
        periodFrom: j['period_from'] as String,
        periodTo: j['period_to'] as String,
        dueDate: j['due_date'] as String,
        vatRate: (j['vat_rate'] as num?)?.toDouble() ?? 0,
        salesBills: _i(j['sales_bills']),
        salesTaxable: _i(j['sales_taxable']),
        salesExempt: _i(j['sales_exempt']),
        outputVat: _i(j['output_vat']),
        purchaseBillsWithVat: _i(j['purchase_bills_with_vat']),
        purchasesTaxable: _i(j['purchases_taxable']),
        inputVat: _i(j['input_vat']),
        carryIn: _i(j['carry_in']),
        payable: _i(j['payable']),
        carryOut: _i(j['carry_out']),
        carryInSource: (j['carry_in_source'] as String?) ?? '',
      );

  final String periodFrom;
  final String periodTo;
  final String dueDate;
  final double vatRate;
  final int salesBills;
  final int salesTaxable;
  final int salesExempt;
  final int outputVat;
  final int purchaseBillsWithVat;
  final int purchasesTaxable;
  final int inputVat;
  final int carryIn;
  final int payable;
  final int carryOut;
  final String carryInSource;
}

class VatFiling {
  const VatFiling({
    required this.id,
    required this.period,
    required this.periodFrom,
    required this.periodTo,
    required this.source,
    required this.salesTaxable,
    required this.salesExempt,
    required this.outputVat,
    required this.purchasesTaxable,
    required this.inputVat,
    required this.carryIn,
    required this.payable,
    required this.carryOut,
    required this.paidAmount,
    this.filedOn,
    this.paidOn,
    this.receiptNo,
    this.note,
  });

  factory VatFiling.fromJson(Json j) => VatFiling(
        id: _i(j['id']),
        period: j['period'] as String,
        periodFrom: j['period_from'] as String,
        periodTo: j['period_to'] as String,
        source: j['source'] as String,
        salesTaxable: _i(j['sales_taxable']),
        salesExempt: _i(j['sales_exempt']),
        outputVat: _i(j['output_vat']),
        purchasesTaxable: _i(j['purchases_taxable']),
        inputVat: _i(j['input_vat']),
        carryIn: _i(j['carry_in']),
        payable: _i(j['payable']),
        carryOut: _i(j['carry_out']),
        filedOn: _sn(j['filed_on']),
        paidAmount: _i(j['paid_amount']),
        paidOn: _sn(j['paid_on']),
        receiptNo: _sn(j['receipt_no']),
        note: _sn(j['note']),
      );

  final int id;

  /// For example `2083-07`.
  final String period;
  final String periodFrom;
  final String periodTo;

  /// `computed` or `manual`.
  final String source;
  final int salesTaxable;
  final int salesExempt;
  final int outputVat;
  final int purchasesTaxable;
  final int inputVat;
  final int carryIn;
  final int payable;
  final int carryOut;
  final String? filedOn;
  final int paidAmount;
  final String? paidOn;
  final String? receiptNo;
  final String? note;
}

class Summary {
  const Summary({
    required this.from,
    required this.to,
    required this.salesTotal,
    required this.vatCollected,
    required this.costOfGoods,
    required this.expensesTotal,
    required this.profit,
    required this.stockValue,
    required this.owedToUs,
    required this.weOwe,
  });

  factory Summary.fromJson(Json j) => Summary(
        from: j['from'] as String,
        to: j['to'] as String,
        salesTotal: _i(j['sales_total']),
        vatCollected: _i(j['vat_collected']),
        costOfGoods: _i(j['cost_of_goods']),
        expensesTotal: _i(j['expenses_total']),
        profit: _i(j['profit']),
        stockValue: _i(j['stock_value']),
        owedToUs: _i(j['owed_to_us']),
        weOwe: _i(j['we_owe']),
      );

  final String from;
  final String to;
  final int salesTotal;
  final int vatCollected;
  final int costOfGoods;
  final int expensesTotal;
  final int profit;
  final int stockValue;
  final int owedToUs;
  final int weOwe;
}

class LedgerSale {
  const LedgerSale({
    required this.id,
    required this.soldAt,
    required this.total,
    required this.returnedTotal,
    required this.paid,
    required this.balance,
    this.billNo,
    this.cancelledAt,
  });

  factory LedgerSale.fromJson(Json j) => LedgerSale(
        id: _i(j['id']),
        billNo: _sn(j['bill_no']),
        soldAt: j['sold_at'] as String,
        total: _i(j['total']),
        returnedTotal: _i(j['returned_total']),
        paid: _i(j['paid']),
        balance: _i(j['balance']),
        cancelledAt: _sn(j['cancelled_at']),
      );

  final int id;
  final String? billNo;
  final String soldAt;
  final int total;
  final int returnedTotal;
  final int paid;
  final int balance;
  final String? cancelledAt;
}

class CustomerLedger {
  const CustomerLedger({
    required this.customer,
    required this.totalSales,
    required this.totalPaid,
    required this.owes,
    required this.sales,
    required this.payments,
    this.creditLimit,
  });

  factory CustomerLedger.fromJson(Json j) => CustomerLedger(
        customer: Customer.fromJson(j['customer'] as Json),
        totalSales: _i(j['total_sales']),
        totalPaid: _i(j['total_paid']),
        owes: _i(j['owes']),
        creditLimit: _in(j['credit_limit']),
        sales: _list(j['sales']).map(LedgerSale.fromJson).toList(),
        payments: _list(j['payments']).map(Payment.fromJson).toList(),
      );

  final Customer customer;
  final int totalSales;
  final int totalPaid;
  final int owes;
  final int? creditLimit;
  final List<LedgerSale> sales;
  final List<Payment> payments;
}

class LedgerPurchase {
  const LedgerPurchase({required this.id, required this.boughtAt, required this.total, required this.paid, required this.balance, this.billNo});

  factory LedgerPurchase.fromJson(Json j) => LedgerPurchase(
        id: _i(j['id']),
        billNo: _sn(j['bill_no']),
        boughtAt: j['bought_at'] as String,
        total: _i(j['total']),
        paid: _i(j['paid']),
        balance: _i(j['balance']),
      );

  final int id;
  final String? billNo;
  final String boughtAt;
  final int total;
  final int paid;
  final int balance;
}

class SupplierLedger {
  const SupplierLedger({
    required this.supplier,
    required this.totalPurchases,
    required this.totalPaid,
    required this.weOwe,
    required this.purchases,
    required this.payments,
  });

  factory SupplierLedger.fromJson(Json j) => SupplierLedger(
        supplier: Supplier.fromJson(j['supplier'] as Json),
        totalPurchases: _i(j['total_purchases']),
        totalPaid: _i(j['total_paid']),
        weOwe: _i(j['we_owe']),
        purchases: _list(j['purchases']).map(LedgerPurchase.fromJson).toList(),
        payments: _list(j['payments']).map(Payment.fromJson).toList(),
      );

  final Supplier supplier;
  final int totalPurchases;
  final int totalPaid;
  final int weOwe;
  final List<LedgerPurchase> purchases;
  final List<Payment> payments;
}

class StockMovement {
  const StockMovement({required this.id, required this.change, required this.reason, required this.at, this.refType, this.refId, this.note, this.by});

  factory StockMovement.fromJson(Json j) => StockMovement(
        id: _i(j['id']),
        change: _i(j['change']),
        reason: j['reason'] as String,
        refType: _sn(j['ref_type']),
        refId: _in(j['ref_id']),
        note: _sn(j['note']),
        by: _sn(j['by']),
        at: j['at'] as String,
      );

  final int id;
  final int change;

  /// `sale`, `sale_return`, `sale_cancel`, `purchase`, `adjust` or `count`.
  final String reason;
  final String? refType;
  final int? refId;
  final String? note;
  final String? by;
  final String at;
}

class CashEntry {
  const CashEntry({required this.kind, required this.id, required this.at, required this.amount, required this.method, required this.balance, this.label});

  factory CashEntry.fromJson(Json j) => CashEntry(
        kind: j['kind'] as String,
        id: _i(j['id']),
        at: j['at'] as String,
        amount: _i(j['amount']),
        method: (j['method'] as String?) ?? 'cash',
        label: _sn(j['label']),
        balance: _i(j['balance']),
      );

  /// `payment_in`, `payment_out`, `refund` or `expense`.
  final String kind;
  final int id;
  final String at;

  /// Negative when money goes out.
  final int amount;
  final String method;
  final String? label;
  final int balance;
}

class CashBook {
  const CashBook({
    required this.from,
    required this.to,
    required this.openingBalance,
    required this.moneyIn,
    required this.moneyOut,
    required this.closingBalance,
    required this.entries,
    required this.total,
  });

  factory CashBook.fromJson(Json j) => CashBook(
        from: j['from'] as String,
        to: j['to'] as String,
        openingBalance: _i(j['opening_balance']),
        moneyIn: _i(j['money_in']),
        moneyOut: _i(j['money_out']),
        closingBalance: _i(j['closing_balance']),
        entries: _list(j['data']).map(CashEntry.fromJson).toList(),
        total: _i((j['meta'] as Json?)?['total']),
      );

  final String from;
  final String to;
  final int openingBalance;
  final int moneyIn;
  final int moneyOut;
  final int closingBalance;
  final List<CashEntry> entries;
  final int total;
}

class DayTotal {
  const DayTotal({required this.date, required this.bills, required this.sales});

  factory DayTotal.fromJson(Json j) => DayTotal(date: j['date'] as String, bills: _i(j['bills']), sales: _i(j['sales']));

  final String date;
  final int bills;
  final int sales;
}

class HourTotal {
  const HourTotal({required this.hour, required this.bills, required this.sales});

  factory HourTotal.fromJson(Json j) => HourTotal(hour: _i(j['hour']), bills: _i(j['bills']), sales: _i(j['sales']));

  final int hour;
  final int bills;
  final int sales;
}

class DailyReport {
  const DailyReport({required this.from, required this.to, required this.days, required this.hours, required this.total, required this.bills});

  factory DailyReport.fromJson(Json j) => DailyReport(
        from: j['from'] as String,
        to: j['to'] as String,
        days: _list(j['days']).map(DayTotal.fromJson).toList(),
        hours: _list(j['hours']).map(HourTotal.fromJson).toList(),
        total: _i(j['total']),
        bills: _i(j['bills']),
      );

  final String from;
  final String to;
  final List<DayTotal> days;
  final List<HourTotal> hours;
  final int total;
  final int bills;
}

class TopItem {
  const TopItem({required this.itemId, required this.name, required this.unit, required this.quantity, required this.revenue});

  factory TopItem.fromJson(Json j) => TopItem(
        itemId: _i(j['item_id']),
        name: j['name'] as String,
        unit: (j['unit'] as String?) ?? 'pcs',
        quantity: _i(j['quantity']),
        revenue: _i(j['revenue']),
      );

  final int itemId;
  final String name;
  final String unit;
  final int quantity;
  final int revenue;
}

class SlowItem {
  const SlowItem({required this.itemId, required this.name, required this.unit, required this.inStock, required this.sold, required this.stockValue});

  factory SlowItem.fromJson(Json j) => SlowItem(
        itemId: _i(j['item_id']),
        name: j['name'] as String,
        unit: (j['unit'] as String?) ?? 'pcs',
        inStock: _i(j['in_stock']),
        sold: _i(j['sold']),
        stockValue: _i(j['stock_value']),
      );

  final int itemId;
  final String name;
  final String unit;
  final int inStock;
  final int sold;
  final int stockValue;
}

class ItemsReport {
  const ItemsReport({required this.top, required this.slow});

  factory ItemsReport.fromJson(Json j) => ItemsReport(
        top: _list(j['top']).map(TopItem.fromJson).toList(),
        slow: _list(j['slow']).map(SlowItem.fromJson).toList(),
      );

  final List<TopItem> top;
  final List<SlowItem> slow;
}

class CreditBucket {
  const CreditBucket({required this.key, required this.label, required this.bills, required this.amount});

  factory CreditBucket.fromJson(Json j) => CreditBucket(
        key: j['key'] as String,
        label: j['label'] as String,
        bills: _i(j['bills']),
        amount: _i(j['amount']),
      );

  /// `d0_30`, `d31_60`, `d61_90` or `d90_plus`.
  final String key;
  final String label;
  final int bills;
  final int amount;
}

class CreditCustomer {
  const CreditCustomer({required this.customerId, required this.owes, required this.oldestDays, required this.bucket, this.name, this.phone});

  factory CreditCustomer.fromJson(Json j) => CreditCustomer(
        customerId: _i(j['customer_id']),
        name: _sn(j['name']),
        phone: _sn(j['phone']),
        owes: _i(j['owes']),
        oldestDays: _i(j['oldest_days']),
        bucket: j['bucket'] as String,
      );

  final int customerId;
  final String? name;
  final String? phone;
  final int owes;
  final int oldestDays;
  final String bucket;
}

class CreditAge {
  const CreditAge({required this.asOf, required this.total, required this.buckets, required this.customers});

  factory CreditAge.fromJson(Json j) => CreditAge(
        asOf: j['as_of'] as String,
        total: _i(j['total']),
        buckets: _list(j['buckets']).map(CreditBucket.fromJson).toList(),
        customers: _list(j['customers']).map(CreditCustomer.fromJson).toList(),
      );

  final String asOf;
  final int total;
  final List<CreditBucket> buckets;
  final List<CreditCustomer> customers;
}

class StaffSales {
  const StaffSales({required this.name, required this.bills, required this.sales, required this.discount, this.userId});

  factory StaffSales.fromJson(Json j) => StaffSales(
        userId: _in(j['user_id']),
        name: j['name'] as String,
        bills: _i(j['bills']),
        sales: _i(j['sales']),
        discount: _i(j['discount']),
      );

  final int? userId;
  final String name;
  final int bills;
  final int sales;
  final int discount;
}

class AppNotification {
  const AppNotification({required this.type, required this.title, required this.body, required this.at, this.count, this.amount, this.dueDate});

  factory AppNotification.fromJson(Json j) => AppNotification(
        type: j['type'] as String,
        title: j['title'] as String,
        body: (j['body'] as String?) ?? '',
        at: j['at'] as String,
        count: _in(j['count']),
        amount: _in(j['amount']),
        dueDate: _sn(j['due_date']),
      );

  /// `low_stock`, `credit_overdue`, `vat_unfiled` or `staff_added`.
  final String type;
  final String title;
  final String body;
  final String at;
  final int? count;
  final int? amount;
  final String? dueDate;
}

class ActivityEntry {
  const ActivityEntry({required this.kind, required this.refId, required this.at, required this.amount, this.by, this.label});

  factory ActivityEntry.fromJson(Json j) => ActivityEntry(
        kind: j['kind'] as String,
        refId: _i(j['ref_id']),
        at: j['at'] as String,
        by: _sn(j['by']),
        label: _sn(j['label']),
        amount: _i(j['amount']),
      );

  final String kind;
  final int refId;
  final String at;
  final String? by;
  final String? label;
  final int amount;
}

class Meta {
  const Meta({required this.currentPage, required this.lastPage, required this.perPage, required this.total});

  factory Meta.fromJson(Json? j) => Meta(
        currentPage: _i(j?['current_page'], 1),
        lastPage: _i(j?['last_page'], 1),
        perPage: _i(j?['per_page'], 20),
        total: _i(j?['total']),
      );

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

/// One page of a list answer: `{ data: [...], meta: {...}, summary?: {...} }`.
class Paged<T> {
  const Paged({required this.items, required this.meta, this.summary = const {}});

  factory Paged.fromJson(Json j, T Function(Json) parse) => Paged(
        items: _list(j['data']).map(parse).toList(),
        meta: Meta.fromJson(j['meta'] as Json?),
        summary: (j['summary'] as Json?) ?? const {},
      );

  final List<T> items;
  final Meta meta;

  /// Extra totals some lists send (customers: `owed_total`, `owing_customers`; suppliers: `owed_total`).
  final Json summary;
}
