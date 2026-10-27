import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/clock_providers.dart';
import '../../app/providers/habit_providers.dart';
import '../../app/providers/log_providers.dart';
import '../../app/providers/theme_mode_provider.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/logic/schedule_logic.dart';
import '../../domain/models/local_day.dart';
import '../habits/habit_detail_screen.dart';
import '../habits/habit_form_screen.dart';
import '../habits/widgets/habit_card.dart';

/// The Today screen: one card per habit, due-today habits first.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onOpenHabit, this.selectedHabitId});

  /// When provided, the shell opens the habit in a side pane instead of pushing.
  final ValueChanged<String>? onOpenHabit;
  final String? selectedHabitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final logsAsync = ref.watch(allLogsProvider);
    final today = ref.watch(effectiveTodayProvider);
    final weekStart = ref.watch(weekStartProvider);
    final themeMode = ref.watch(themeModeProvider);

    Future<void> openForm([Habit? habit]) {
      return Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HabitFormScreen(existing: habit),
        ),
      );
    }

    final habits = habitsAsync.value;
    final logs = logsAsync.value;

    Widget body;
    if (habitsAsync.hasError) {
      body = _ErrorState(error: habitsAsync.error!);
    } else if (logsAsync.hasError) {
      body = _ErrorState(error: logsAsync.error!);
    } else if (habits == null || logs == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (habits.isEmpty) {
      body = _EmptyState(onCreate: () => openForm());
    } else {
      final logsByHabit = _groupLogsByHabit(logs);
      final sorted = _sortHabits(habits, today);
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final habit = sorted[index];
          return HabitCard(
            habit: habit,
            logs: logsByHabit[habit.id] ?? const <LocalDay, HabitLog>{},
            today: today,
            weekStart: weekStart,
            selected: selectedHabitId == habit.id,
            onEdit: () => openForm(habit),
            onOpen: () {
              if (onOpenHabit != null) {
                onOpenHabit!(habit.id);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HabitDetailScreen(habitId: habit.id),
                ),
              );
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 34),
            const SizedBox(width: 10),
            Text(AppConstants.appName),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch theme',
            onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
            icon: Icon(_themeIcon(themeMode)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
              ? Duration.zero
              : const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey('${habits?.isEmpty}-${habits == null}'),
            child: body,
          ),
        ),
      ),
      floatingActionButton: (habits != null && habits.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New habit'),
            )
          : null,
    );
  }

  IconData _themeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => Icons.dark_mode_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.system => Icons.brightness_auto_rounded,
  };

  Map<String, Map<LocalDay, HabitLog>> _groupLogsByHabit(
    List<HabitLog> logs,
  ) {
    final byHabit = <String, Map<LocalDay, HabitLog>>{};
    for (final log in logs) {
      (byHabit[log.habitId] ??= <LocalDay, HabitLog>{})[log.date] = log;
    }
    return byHabit;
  }

  List<Habit> _sortHabits(List<Habit> habits, LocalDay today) {
    final sorted = [...habits];
    sorted.sort((a, b) {
      final aDue = isHabitDueOn(a, today) ? 0 : 1;
      final bDue = isHabitDueOn(b, today) ? 0 : 1;
      if (aDue != bDue) return aDue.compareTo(bDue);

      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }
}

/// The rounded-square flash brand mark, used in the app bar and empty state.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(
        Icons.bolt_rounded,
        size: size * 0.58,
        color: const Color(0xFF052012),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 88),
              const SizedBox(height: 28),
              Text(
                'No habits yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '${AppConstants.tagline}\n'
                'Add your first habit and it will show up here as a card.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add your first habit'),
                ),
              ),
              const SizedBox(height: 22),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(icon: Icons.offline_bolt_rounded, label: 'Offline-first'),
                  _Pill(icon: Icons.dark_mode_rounded, label: 'Dark & light'),
                  _Pill(icon: Icons.devices_rounded, label: 'Android + Windows'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong loading your habits',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
