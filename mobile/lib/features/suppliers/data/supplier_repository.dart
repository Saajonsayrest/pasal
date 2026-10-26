import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

/// What the suppliers list shows: a search text and the "we owe" filter.
typedef SupplierQuery = ({String search, bool owedOnly});

class SupplierList {
  const SupplierList({required this.suppliers, required this.owedTotal, required this.total});

  final List<Supplier> suppliers;

  /// Paisa we owe all suppliers together.
  final int owedTotal;

  /// Suppliers that match the search, not only the ones on this page.
  final int total;
}

/// Talks to /suppliers and the supplier payments. Screens go through this and the providers below.
class SupplierRepository {
  SupplierRepository(this._api);

  final ApiClient _api;

  Future<SupplierList> list(SupplierQuery q) async {
    final page = await _api.page(
      '/suppliers',
      Supplier.fromJson,
      query: {'search': q.search, 'owed': q.owedOnly ? true : null, 'per_page': 50},
    );
    return SupplierList(
      suppliers: page.items,
      owedTotal: (page.summary['owed_total'] as num?)?.toInt() ?? 0,
      total: page.meta.total,
    );
  }

  /// Every supplier, for the pickers.
  Future<List<Supplier>> all() => _api.all('/suppliers', Supplier.fromJson, perPage: 50);

  Future<Supplier> get(int id) async => Supplier.fromJson((await _api.get('/suppliers/$id'))['data'] as Json);

  /// Not wrapped in `data`.
  Future<SupplierLedger> ledger(int id) async => SupplierLedger.fromJson(await _api.get('/suppliers/$id/ledger'));

  /// Creates a supplier when [id] is null, otherwise updates it.
  Future<Supplier> save(int? id, Json body) async {
    final res = id == null ? await _api.post('/suppliers', body: body) : await _api.patch('/suppliers/$id', body: body);
    return Supplier.fromJson(res['data'] as Json);
  }

  Future<void> delete(int id) async {
    await _api.delete('/suppliers/$id');
  }

  /// Pays a supplier's oldest bills first. Returns the paisa still owed.
  Future<int> payOldestFirst({required int supplierId, required int amount, required String method, required String key}) async {
    final res = await _api.post('/payments', body: {'supplier_id': supplierId, 'amount': amount, 'method': method}, key: key);
    return (res['owes_left'] as num).toInt();
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) => SupplierRepository(ref.watch(apiClientProvider)));

final suppliersProvider = FutureProvider.autoDispose.family<SupplierList, SupplierQuery>(
  (ref, q) => ref.watch(supplierRepositoryProvider).list(q),
);

final allSuppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) => ref.watch(supplierRepositoryProvider).all());

final supplierProvider = FutureProvider.autoDispose.family<Supplier, int>(
  (ref, id) => ref.watch(supplierRepositoryProvider).get(id),
);

final supplierLedgerProvider = FutureProvider.autoDispose.family<SupplierLedger, int>(
  (ref, id) => ref.watch(supplierRepositoryProvider).ledger(id),
);
