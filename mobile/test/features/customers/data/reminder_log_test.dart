import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/features/customers/data/reminder_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('nothing is sent until a reminder is marked', () async {
    SharedPreferences.setMockInitialValues({});
    final log = ReminderLog(await SharedPreferences.getInstance());
    expect(log.sentFor(4), isNull);
  });

  test('a sent reminder is saved per customer under pasal_reminders', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final log = ReminderLog(prefs);

    final sent = await log.markSent(4, 'whatsapp', DateTime.utc(2026, 10, 26, 6, 30));
    expect(sent.at, '2026-10-26T06:30:00.000Z');

    final back = log.sentFor(4);
    expect(back?.channel, 'whatsapp');
    expect(back?.at, '2026-10-26T06:30:00.000Z');
    expect(log.sentFor(5), isNull);
    expect(prefs.getString(ReminderLog.storageKey), contains('"4"'));
  });

  test('a broken saved value is read as nothing sent', () async {
    SharedPreferences.setMockInitialValues({ReminderLog.storageKey: 'not json'});
    final log = ReminderLog(await SharedPreferences.getInstance());
    expect(log.sentFor(4), isNull);
  });

  test('a later reminder replaces the channel of the earlier one', () async {
    SharedPreferences.setMockInitialValues({});
    final log = ReminderLog(await SharedPreferences.getInstance());
    await log.markSent(4, 'whatsapp', DateTime.utc(2026, 10, 25));
    await log.markSent(4, 'sms', DateTime.utc(2026, 10, 26));
    expect(log.sentFor(4)?.channel, 'sms');
  });
}
