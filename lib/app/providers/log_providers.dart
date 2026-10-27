import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_log_repository.dart';
import '../../data/services/habit_log_service.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/repositories/log_repository.dart';
import 'database_provider.dart';

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return DriftLogRepository(ref.watch(appDatabaseProvider));
});

/// The single writer for habit logs (manual taps, and later notification,
/// widget and integration sources).
final logServiceProvider = Provider<HabitLogService>((ref) {
  return HabitLogService(ref.watch(logRepositoryProvider));
});

/// Every active log, streamed from Drift.
final allLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  return ref.watch(logRepositoryProvider).watchAllLogs();
});
