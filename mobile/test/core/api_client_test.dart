import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/network/api_client.dart';

/// Answers every request with one prepared answer and remembers what was asked.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body, {this.fail = false});

  final int status;
  final Object? body;
  final bool fail;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (fail) throw DioException.connectionError(requestOptions: options, reason: 'no network');
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_Adapter adapter, {void Function()? onUnauthorized}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake.test/api/v1', validateStatus: (_) => true))..httpClientAdapter = adapter;
  return ApiClient(baseUrl: 'http://fake.test/api/v1', dio: dio, onUnauthorized: onUnauthorized);
}

void main() {
  test('sends the token, the idempotency key and drops empty query values', () async {
    final adapter = _Adapter(201, {'data': {'id': 1}});
    final api = _client(adapter)..setToken('12|abc');

    await api.post('/sales', body: {'paid': 100}, key: 'key-1');
    await api.get('/items', query: {'search': '', 'low_stock': true, 'page': 2, 'x': null});

    expect(adapter.requests[0].headers['Authorization'], 'Bearer 12|abc');
    expect(adapter.requests[0].headers['Idempotency-Key'], 'key-1');
    expect(adapter.requests[1].headers.containsKey('Idempotency-Key'), isFalse);
    expect(adapter.requests[1].uri.queryParameters, {'low_stock': '1', 'page': '2'});
  });

  test('a 422 becomes field errors the screen can show', () async {
    final api = _client(_Adapter(422, {'message': 'The name field is required.', 'errors': {'name': ['The name field is required.']}}));
    await expectLater(
      api.post('/items', body: {}),
      throwsA(isA<ApiException>().having((e) => e.field('name'), 'name', 'The name field is required.').having((e) => e.isValidation, 'validation', isTrue)),
    );
  });

  test('keeps the whole body, for example the existing item of a duplicate name', () async {
    final api = _client(_Adapter(422, {'message': 'exists', 'errors': {'name': ['exists']}, 'existing_item': {'id': 7, 'name': 'Rice', 'deleted': false}}));
    try {
      await api.post('/items', body: {});
      fail('should throw');
    } on ApiException catch (e) {
      expect((e.body['existing_item'] as Json)['id'], 7);
    }
  });

  test('a 401 with a token tells the app to log out, without a token it does not', () async {
    var calls = 0;
    final withToken = _client(_Adapter(401, {'message': 'Unauthenticated.'}), onUnauthorized: () => calls++)..setToken('t');
    await expectLater(withToken.get('/me'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(calls, 1);

    final noToken = _client(_Adapter(401, {'message': 'Unauthenticated.'}), onUnauthorized: () => calls++);
    await expectLater(noToken.post('/login', body: {}), throwsA(isA<ApiException>()));
    expect(calls, 1);
  });

  test('no network gives status 0 and a plain message', () async {
    final api = _client(_Adapter(200, {}, fail: true));
    await expectLater(api.get('/me'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'network', isTrue)));
  });

  test('a server error without a body still has a message', () async {
    final api = _client(_Adapter(500, null));
    await expectLater(api.get('/me'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Something went wrong.')));
  });

  test('all() reads every page', () async {
    var page = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test/api/v1', validateStatus: (_) => true));
    dio.httpClientAdapter = _PagedAdapter(() => ++page);
    final api = ApiClient(baseUrl: 'http://fake.test/api/v1', dio: dio);
    final rows = await api.all('/categories', Category.fromJson, perPage: 2);
    expect(rows.map((c) => c.name), ['A', 'B', 'C']);
  });
}

class _PagedAdapter implements HttpClientAdapter {
  _PagedAdapter(this.next);

  final int Function() next;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final page = int.parse(options.uri.queryParameters['page']!);
    final rows = page == 1 ? ['A', 'B'] : ['C'];
    next();
    return ResponseBody.fromString(
      jsonEncode({
        'data': [for (var i = 0; i < rows.length; i++) {'id': page * 10 + i, 'name': rows[i], 'icon': null, 'color': null}],
        'meta': {'current_page': page, 'last_page': 2, 'per_page': 2, 'total': 3},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
