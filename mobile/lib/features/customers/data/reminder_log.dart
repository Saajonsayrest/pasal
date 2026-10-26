import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When a reminder was sent to a customer, and by which channel.
class SentReminder {
  const SentReminder({required this.at, required this.channel});

  /// UTC time stamp (ISO 8601).
  final String at;

  /// `whatsapp` or `sms`.
  final String channel;
}

/// The "sent" tick of the reminder screen. One entry per customer, saved on this phone only.
class ReminderLog {
  ReminderLog(this._prefs);

  static const storageKey = 'pasal_reminders';

  final SharedPreferences _prefs;

  Map<String, dynamic> _read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  SentReminder? sentFor(int customerId) {
    final entry = _read()['$customerId'];
    if (entry is! Map) return null;
    final at = entry['at'];
    final channel = entry['channel'];
    if (at is! String || channel is! String) return null;
    return SentReminder(at: at, channel: channel);
  }

  Future<SentReminder> markSent(int customerId, String channel, DateTime now) async {
    final all = _read();
    final sent = SentReminder(at: now.toUtc().toIso8601String(), channel: channel);
    all['$customerId'] = {'at': sent.at, 'channel': sent.channel};
    await _prefs.setString(storageKey, jsonEncode(all));
    return sent;
  }
}

final reminderLogProvider = Provider<ReminderLog>((ref) => ReminderLog(ref.watch(sharedPrefsProvider)));
