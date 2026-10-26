import 'package:pasal_mobile/core/network/api_client.dart';

/// The Idempotency-Key of one save screen. Retries of the same body reuse the key. A new key is made
/// when the body changes (the server refuses a reused key with a different body) and after a save.
class SaveKey {
  String? _key;
  String? _body;

  String forBody(String body) {
    if (_key == null || body != _body) {
      _key = newKey();
      _body = body;
    }
    return _key!;
  }

  void reset() {
    _key = null;
    _body = null;
  }
}
