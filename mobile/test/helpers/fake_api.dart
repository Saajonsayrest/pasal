import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';

typedef FakeHandler = Object? Function(Query? query, Object? body);

/// An [ApiClient] for tests. No network. Register an answer per request:
///
///     final api = FakeApi()
///       ..on('GET', '/customers', (q, b) => {'data': [...], 'meta': {...}, 'summary': {...}})
///       ..on('POST', '/payments', (q, b) => throw ApiException(422, 'No', errors: {'amount': ['Too much']}));
///
/// A handler returns the JSON map, or throws an [ApiException]. A request nobody registered fails the test.
class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'http://fake.test/api/v1');

  final Map<String, FakeHandler> _handlers = {};

  /// Every request made, as "GET /customers".
  final List<String> calls = [];

  /// Bodies sent, by "POST /payments".
  final Map<String, List<Object?>> bodies = {};

  /// Idempotency keys sent, by "POST /payments".
  final Map<String, List<String?>> keys = {};

  /// Answers every request that has no handler of its own: (method, path, query, body). Used by the whole app smoke test.
  Object? Function(String method, String path, Query? query, Object? body)? fallback;

  void on(String method, String path, FakeHandler handler) => _handlers['$method $path'] = handler;

  Future<Json> _answer(String method, String path, Query? query, Object? body, String? key) async {
    final id = '$method $path';
    calls.add(id);
    bodies.putIfAbsent(id, () => []).add(body);
    keys.putIfAbsent(id, () => []).add(key);
    final handler = _handlers[id];
    if (handler == null) {
      final other = fallback;
      if (other == null) throw StateError('FakeApi: no handler for $id');
      return (other(method, path, query, body) as Map).cast<String, dynamic>();
    }
    return (handler(query, body) as Map).cast<String, dynamic>();
  }

  @override
  Future<Json> get(String path, {Query? query}) => _answer('GET', path, query, null, null);

  @override
  Future<Json> post(String path, {Object? body, String? key}) => _answer('POST', path, null, body, key);

  @override
  Future<Json> put(String path, {Object? body}) => _answer('PUT', path, null, body, null);

  @override
  Future<Json> patch(String path, {Object? body}) => _answer('PATCH', path, null, body, null);

  @override
  Future<Json> delete(String path) => _answer('DELETE', path, null, null, null);
}

/// A list answer in the API shape.
Json pagedJson(List<Json> rows, {Json summary = const {}, int page = 1, int lastPage = 1}) => {
      'data': rows,
      'meta': {'current_page': page, 'last_page': lastPage, 'per_page': 50, 'total': rows.length},
      if (summary.isNotEmpty) 'summary': summary,
    };
