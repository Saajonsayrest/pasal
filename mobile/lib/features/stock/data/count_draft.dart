import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const countDraftKey = 'pasal_count_draft';

/// What was typed into the stock count screen and not saved yet. Kept on the phone so a closed app keeps it.
class CountDraft {
  const CountDraft({this.counts = const {}, this.note = ''});

  /// Typed text by item id, for example `{'7': '12'}`.
  final Map<String, String> counts;
  final String note;

  bool get isEmpty => counts.isEmpty && note.isEmpty;

  factory CountDraft.fromRaw(String? raw) {
    if (raw == null) return const CountDraft();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final counts = (json['counts'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, '$v'));
      return CountDraft(counts: counts, note: json['note'] as String? ?? '');
    } on FormatException catch (_) {
      return const CountDraft();
    } on TypeError catch (_) {
      return const CountDraft();
    }
  }

  String encode() => jsonEncode({'counts': counts, 'note': note});
}

CountDraft loadCountDraft(SharedPreferences prefs) => CountDraft.fromRaw(prefs.getString(countDraftKey));

/// Saves the draft. An empty draft removes the saved copy.
Future<void> saveCountDraft(SharedPreferences prefs, CountDraft draft) {
  if (draft.isEmpty) return prefs.remove(countDraftKey);
  return prefs.setString(countDraftKey, draft.encode());
}
