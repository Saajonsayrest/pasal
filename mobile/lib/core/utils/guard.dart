import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pasal_mobile/core/network/api_client.dart';

/// Runs a save. Returns the result, or null when it failed (the error goes to [onError]).
///
///     final saved = await guard(() => repo.save(...), onError: (e) => setState(() => error = e));
Future<T?> guard<T>(Future<T> Function() action, {required void Function(ApiException error) onError}) async {
  try {
    return await action();
  } on ApiException catch (e) {
    onError(e);
    return null;
  }
}

/// Wait until typing stops. Create one per search box and call `run` on each change.
///
///     final _debounce = Debouncer(const Duration(milliseconds: 250));
///     onChanged: (v) => _debounce.run(() => setState(() => term = v))
class Debouncer {
  Debouncer([this.delay = const Duration(milliseconds: 250)]);

  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}
