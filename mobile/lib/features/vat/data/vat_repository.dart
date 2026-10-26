import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

/// A range of AD dates, both days included.
typedef VatRange = ({String from, String to});

/// A computed preview for a range, with the opening carry the user typed.
typedef VatPreviewQuery = ({String from, String to, int openingCarry});

/// A return typed in by hand, for an old month. All amounts are paisa.
class ManualReturn {
  const ManualReturn({
    required this.period,
    required this.from,
    required this.to,
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
    this.receiptNo,
  });

  final String period;
  final String from;
  final String to;
  final int salesTaxable;
  final int salesExempt;
  final int outputVat;
  final int purchasesTaxable;
  final int inputVat;
  final int carryIn;
  final int payable;
  final int carryOut;
  final int paidAmount;
  final String? filedOn;
  final String? receiptNo;

  Map<String, Object?> toJson() => {
        'manual': true,
        'period': period,
        'from': from,
        'to': to,
        'sales_taxable': salesTaxable,
        'sales_exempt': salesExempt,
        'output_vat': outputVat,
        'purchases_taxable': purchasesTaxable,
        'input_vat': inputVat,
        'carry_in': carryIn,
        'payable': payable,
        'carry_out': carryOut,
        'filed_on': filedOn,
        'paid_amount': paidAmount,
        'receipt_no': receiptNo,
      };
}

/// The fields a filing can change after it is saved. The numbers stay frozen.
class FilingMarks {
  const FilingMarks({required this.paidAmount, this.filedOn, this.paidOn, this.receiptNo, this.note});

  final String? filedOn;
  final int paidAmount;
  final String? paidOn;
  final String? receiptNo;
  final String? note;

  Map<String, Object?> toJson() => {
        'filed_on': filedOn,
        'paid_amount': paidAmount,
        'paid_on': paidOn,
        'receipt_no': receiptNo,
        'note': note,
      };
}

/// Talks to the VAT and book endpoints. Screens reach it through the providers below.
class VatRepository {
  VatRepository(this._api);

  final ApiClient _api;

  Future<VatPreview> preview(VatPreviewQuery q) async => VatPreview.fromJson(
        await _api.get('/vat/preview', query: {'from': q.from, 'to': q.to, 'opening_carry': q.openingCarry}),
      );

  Future<Paged<VatFiling>> filings({int page = 1, int perPage = 20}) =>
      _api.page('/vat/filings', VatFiling.fromJson, query: {'page': page, 'per_page': perPage});

  Future<VatFiling> filing(int id) async => VatFiling.fromJson((await _api.get('/vat/filings/$id'))['data'] as Json);

  Future<VatFiling> saveComputed({
    required String period,
    required String from,
    required String to,
    required int openingCarry,
    required String key,
  }) async {
    final res = await _api.post(
      '/vat/filings',
      body: {'period': period, 'from': from, 'to': to, 'opening_carry': openingCarry},
      key: key,
    );
    return VatFiling.fromJson(res['data'] as Json);
  }

  Future<VatFiling> saveManual(ManualReturn ret, {required String key}) async {
    final res = await _api.post('/vat/filings', body: ret.toJson(), key: key);
    return VatFiling.fromJson(res['data'] as Json);
  }

  Future<VatFiling> updateMarks(int id, FilingMarks marks) async {
    final res = await _api.patch('/vat/filings/$id', body: marks.toJson());
    return VatFiling.fromJson(res['data'] as Json);
  }

  Future<Paged<Sale>> salesPage(VatRange range, {int page = 1, int perPage = 50}) => _api.page(
        '/sales',
        Sale.fromJson,
        query: {'from': range.from, 'to': range.to, 'per_page': perPage, 'page': page},
      );

  Future<Paged<Purchase>> purchasesPage(VatRange range, {int page = 1, int perPage = 50}) => _api.page(
        '/purchases',
        Purchase.fromJson,
        query: {'from': range.from, 'to': range.to, 'per_page': perPage, 'page': page},
      );

  Future<List<Sale>> allSales(VatRange range) => _api.all('/sales', Sale.fromJson, query: {'from': range.from, 'to': range.to});

  Future<List<Purchase>> allPurchases(VatRange range) => _api.all('/purchases', Purchase.fromJson, query: {'from': range.from, 'to': range.to});
}

final vatRepositoryProvider = Provider<VatRepository>((ref) => VatRepository(ref.watch(apiClientProvider)));

final vatPreviewProvider = FutureProvider.autoDispose.family<VatPreview, VatPreviewQuery>(
  (ref, q) => ref.watch(vatRepositoryProvider).preview(q),
);

/// The newest filings. The argument is the page size.
final vatFilingsProvider = FutureProvider.autoDispose.family<Paged<VatFiling>, int>(
  (ref, perPage) => ref.watch(vatRepositoryProvider).filings(perPage: perPage),
);

final vatFilingProvider = FutureProvider.autoDispose.family<VatFiling, int>(
  (ref, id) => ref.watch(vatRepositoryProvider).filing(id),
);

final vatSalesBookProvider = FutureProvider.autoDispose.family<Paged<Sale>, VatRange>(
  (ref, range) => ref.watch(vatRepositoryProvider).salesPage(range),
);

final vatPurchaseBookProvider = FutureProvider.autoDispose.family<Paged<Purchase>, VatRange>(
  (ref, range) => ref.watch(vatRepositoryProvider).purchasesPage(range),
);
