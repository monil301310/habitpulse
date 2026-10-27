import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_habit_repository.dart';
import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import 'database_provider.dart';

/// The active habit repository. Tests override this with a fake.
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return DriftHabitRepository(ref.watch(appDatabaseProvider));
});

/// A live list of the user's active habits, newest state pushed by Drift.
final habitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).watchHabits();
});
