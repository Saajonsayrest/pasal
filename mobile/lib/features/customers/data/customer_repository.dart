import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';
import 'package:pasal_mobile/core/providers.dart';

/// What the customers list shows. A record has equality built in, so it can be a provider family key.
typedef CustomerQuery = ({String search, String filter, String sort});

class CustomerList {
  const CustomerList({required this.customers, required this.owedTotal, required this.owingCustomers});

  final List<Customer> customers;

  /// Paisa the whole business has to collect.
  final int owedTotal;
  final int owingCustomers;
}

/// Talks to /customers. Screens never call [ApiClient] directly for data, they go through a repository
/// and a provider, so a test can replace the repository.
class CustomerRepository {
  CustomerRepository(this._api);

  final ApiClient _api;

  Future<CustomerList> list(CustomerQuery q) async {
    final page = await _api.page(
      '/customers',
      Customer.fromJson,
      query: {
        'search': q.search,
        'sort': q.sort,
        'owes': q.filter == 'owes',
        'over_limit': q.filter == 'over_limit',
        'paid_up': q.filter == 'paid_up',
        'per_page': 50,
      },
    );
    return CustomerList(
      customers: page.items,
      owedTotal: (page.summary['owed_total'] as num?)?.toInt() ?? 0,
      owingCustomers: (page.summary['owing_customers'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Customer> get(int id) async => Customer.fromJson((await _api.get('/customers/$id'))['data'] as Json);

  Future<CustomerLedger> ledger(int id) async => CustomerLedger.fromJson(await _api.get('/customers/$id/ledger'));

  Future<Customer> create(Json body) async => Customer.fromJson((await _api.post('/customers', body: body))['data'] as Json);

  Future<Customer> update(int id, Json body) async => Customer.fromJson((await _api.patch('/customers/$id', body: body))['data'] as Json);

  Future<void> delete(int id) async {
    await _api.delete('/customers/$id');
  }

  /// Money in against the customer's oldest bills. Returns what the customer still owes, in paisa.
  Future<int> takePayment({required int customerId, required int amount, required String method, required String key}) async {
    final res = await _api.post('/payments', body: {'customer_id': customerId, 'amount': amount, 'method': method}, key: key);
    return (res['owes_left'] as num).toInt();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) => CustomerRepository(ref.watch(apiClientProvider)));

final customersProvider = FutureProvider.autoDispose.family<CustomerList, CustomerQuery>(
  (ref, query) => ref.watch(customerRepositoryProvider).list(query),
);

final customerProvider = FutureProvider.autoDispose.family<Customer, int>(
  (ref, id) => ref.watch(customerRepositoryProvider).get(id),
);

final customerLedgerProvider = FutureProvider.autoDispose.family<CustomerLedger, int>(
  (ref, id) => ref.watch(customerRepositoryProvider).ledger(id),
);
