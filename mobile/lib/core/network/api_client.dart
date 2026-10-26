import 'package:dio/dio.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:uuid/uuid.dart';

/// An answer that was not 2xx, or no answer at all ([status] 0).
class ApiException implements Exception {
  ApiException(this.status, this.message, {this.errors = const {}, this.body = const {}});

  final int status;
  final String message;

  /// Field errors from a 422: `{ "name": ["The name field is required."] }`.
  final Map<String, List<String>> errors;

  /// The whole JSON body (for example `existing_item` on a duplicate item name).
  final Json body;

  bool get isNetwork => status == 0;
  bool get isValidation => status == 422;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;

  /// First message for one field, or null.
  String? field(String name) {
    final list = errors[name];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  /// A general message to show when no single field holds it.
  String? get general => errors.isEmpty ? message : null;

  @override
  String toString() => 'ApiException($status, $message)';
}

/// A new random key for one tap of a save button. Reuse it for every retry of that same tap.
String newKey() => const Uuid().v4();

typedef Query = Map<String, Object?>;

/// The only place that talks HTTP. Everything returns JSON maps; models are built by the callers.
/// Money is whole paisa, as the API sends it.
class ApiClient {
  ApiClient({required String baseUrl, this.onUnauthorized, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {'Accept': 'application/json'},
                validateStatus: (_) => true,
              ),
            );

  final Dio _dio;

  /// Called on any 401 while a token was sent (token expired or revoked).
  final void Function()? onUnauthorized;

  String? _token;

  void setToken(String? token) => _token = token;

  bool get hasToken => _token != null;

  Map<String, String> _headers(String? key) => {
        if (_token != null) 'Authorization': 'Bearer $_token',
        'Idempotency-Key': ?key,
      };

  static Query _clean(Query? query) {
    final out = <String, Object?>{};
    query?.forEach((k, v) {
      if (v == null || v == '') return;
      out[k] = v is bool ? (v ? 1 : 0) : v;
    });
    return out;
  }

  Future<Json> _send(String method, String path, {Query? query, Object? body, String? key}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: _clean(query),
        options: Options(method: method, headers: _headers(key), contentType: body is FormData ? null : Headers.jsonContentType),
      );
    } on DioException catch (e) {
      throw ApiException(0, 'Cannot reach the server. Check the connection and try again.', body: {'type': e.type.name});
    }

    final status = res.statusCode ?? 0;
    final data = res.data;
    final json = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (status >= 200 && status < 300) return json;

    if (status == 401 && _token != null) onUnauthorized?.call();
    final errors = <String, List<String>>{};
    final raw = json['errors'];
    if (raw is Map) {
      raw.forEach((k, v) => errors['$k'] = (v as List<dynamic>).map((e) => '$e').toList());
    }
    final message = (json['message'] as String?) ?? (status == 429 ? 'Too many tries. Wait a moment.' : 'Something went wrong.');
    throw ApiException(status, message, errors: errors, body: json);
  }

  Future<Json> get(String path, {Query? query}) => _send('GET', path, query: query);

  /// Pass [key] (from [newKey]) on any POST that saves a sale, payment, return, purchase or stock change.
  Future<Json> post(String path, {Object? body, String? key}) => _send('POST', path, body: body ?? <String, dynamic>{}, key: key);

  Future<Json> put(String path, {Object? body}) => _send('PUT', path, body: body ?? <String, dynamic>{});

  Future<Json> patch(String path, {Object? body}) => _send('PATCH', path, body: body ?? <String, dynamic>{});

  Future<Json> delete(String path) => _send('DELETE', path);

  /// Upload one file as multipart form data (item photo: field `photo`).
  Future<Json> upload(String path, {required String field, required String filePath, String? filename}) async {
    final form = FormData.fromMap({field: await MultipartFile.fromFile(filePath, filename: filename)});
    return _send('POST', path, body: form);
  }

  /// One page of a list answer.
  Future<Paged<T>> page<T>(String path, T Function(Json) parse, {Query? query}) async => Paged.fromJson(await get(path, query: query), parse);

  /// Every page of a list (use for small lists such as categories). Stops after [maxPages].
  Future<List<T>> all<T>(String path, T Function(Json) parse, {Query? query, int perPage = 50, int maxPages = 100}) async {
    final out = <T>[];
    for (var page = 1; page <= maxPages; page++) {
      final res = await this.page(path, parse, query: {...?query, 'per_page': perPage, 'page': page});
      out.addAll(res.items);
      if (!res.meta.hasMore) break;
    }
    return out;
  }
}
