import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/entities/habit_reminder.dart';
import '../../domain/export/export_builder.dart';

class ExportResult {
  const ExportResult({
    required this.path,
    required this.format,
    required this.count,
  });

  final String path;
  final String format;
  final int count;
}

/// Writes exports to a user-visible folder and opens the share sheet on Android.
class ExportService {
  Future<ExportResult> exportJson({
    required List<Habit> habits,
    required List<HabitLog> logs,
    required List<HabitReminder> reminders,
    required AppSettings settings,
  }) async {
    final content = ExportBuilder.toJson(
      habits: habits,
      reminders: reminders,
      logs: logs,
      settings: settings,
      exportedAt: DateTime.now(),
    );
    final path = await _write(
      'habitpulse-${_stamp(DateTime.now())}.json',
      content,
    );
    return ExportResult(path: path, format: 'json', count: logs.length);
  }

  Future<ExportResult> exportCsv({
    required List<Habit> habits,
    required List<HabitLog> logs,
  }) async {
    final content = ExportBuilder.toCsv(habits: habits, logs: logs);
    final path = await _write(
      'habitpulse-logs-${_stamp(DateTime.now())}.csv',
      content,
    );
    return ExportResult(path: path, format: 'csv', count: logs.length);
  }

  Future<void> share(ExportResult result) async {
    if (!Platform.isAndroid) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.path)],
        subject: 'HabitPulse export',
      ),
    );
  }

  Future<void> reveal(ExportResult result) async {
    if (!Platform.isWindows) return;
    await Process.start(
      'explorer.exe',
      ['/select,', result.path],
      mode: ProcessStartMode.detached,
    );
  }

  Future<String> _write(String name, String content) async {
    final directory =
        (Platform.isWindows ? await getDownloadsDirectory() : null) ??
        await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  String _stamp(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}';
  }
}
