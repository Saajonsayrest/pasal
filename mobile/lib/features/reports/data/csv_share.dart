import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/features/reports/data/csv.dart';
import 'package:share_plus/share_plus.dart';

/// Hands the CSV files to the phone's share sheet. Tests replace it with a recorder.
typedef CsvSharer = Future<void> Function(List<CsvFile> files);

Future<void> shareCsvFiles(List<CsvFile> files) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [for (final f in files) XFile.fromData(csvBytes(f.text), name: f.name, mimeType: 'text/csv')],
      fileNameOverrides: [for (final f in files) f.name],
    ),
  );
}

final csvSharerProvider = Provider<CsvSharer>((ref) => shareCsvFiles);
