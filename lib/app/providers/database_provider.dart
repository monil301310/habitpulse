import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';

/// The single, long-lived local database instance.
///
/// Disposed automatically when the [ProviderScope] is torn down, which closes
/// the underlying SQLite file cleanly.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});
