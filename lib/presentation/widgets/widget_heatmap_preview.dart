import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/constants/habit_icons.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/enums/log_status.dart';
import '../../domain/logic/streak_logic.dart';
import '../../domain/models/local_day.dart';
import '../habits/widgets/heatmap.dart';

/// The heatmap widget rendered to a PNG for the Android home screen.
class WidgetHeatmapPreview extends StatelessWidget {
  const WidgetHeatmapPreview({
    super.key,
    required this.habit,
    required this.logs,
    required this.today,
    required this.weekStart,
  });

  final Habit habit;
  final Map<LocalDay, HabitLog> logs;
  final LocalDay today;
  final int weekStart;

  @override
  Widget build(BuildContext context) {
    final isDark =
        PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    final theme = isDark ? AppTheme.dark : AppTheme.light;
    final accent = AppColors.fromHex(habit.colour);
    final streak = currentStreak(
      habit: habit,
      logs: logs,
      today: today,
      weekStart: weekStart,
    );
    final done = logs[today]?.status == LogStatus.done;

    return Theme(
      data: theme,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Container(
          width: 300,
          height: 160,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      HabitIcons.resolve(habit.icon),
                      size: 15,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      streak.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: HabitHeatmap(
                  habit: habit,
                  logs: logs,
                  today: today,
                  cellSize: 8,
                  gap: 2.5,
                  maxWeeks: 24,
                  showWeekdayLabels: false,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 13,
                    color: done ? accent : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    done ? 'Done today' : 'Open today',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
