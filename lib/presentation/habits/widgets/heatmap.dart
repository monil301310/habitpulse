import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/habit_log.dart';
import '../../../domain/logic/heatmap_logic.dart';
import '../../../domain/logic/schedule_logic.dart';
import '../../../domain/models/local_day.dart';

/// A horizontally scrollable, custom-painted rounded-square heatmap.
///
/// One column per week (Monday first), seven rows for Monday–Sunday, newest
/// week on the right. It auto-scrolls to today on first layout and can be
/// scrolled back through the habit's full history.
class HabitHeatmap extends StatefulWidget {
  const HabitHeatmap({
    super.key,
    required this.habit,
    required this.logs,
    required this.today,
    this.cellSize = 14,
    this.gap = 4,
    this.maxWeeks = 156,
    this.onDayTap,
    this.showWeekdayLabels = true,
  });

  final Habit habit;
  final Map<LocalDay, HabitLog> logs;
  final LocalDay today;
  final double cellSize;
  final double gap;

  /// Upper bound on columns (156 ≈ three years).
  final int maxWeeks;

  final ValueChanged<LocalDay>? onDayTap;
  final bool showWeekdayLabels;

  @override
  State<HabitHeatmap> createState() => _HabitHeatmapState();
}

class _HabitHeatmapState extends State<HabitHeatmap> {
  static const List<String> _weekdayLabels = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  final ScrollController _controller = ScrollController();

  int? _lastWeekCount;
  int _totalWeeks = 1;
  double _step = 18;
  LocalDay _firstWeekStart = const LocalDay(2024, 1, 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.fromHex(widget.habit.colour);
    final step = widget.cellSize + widget.gap;

    final currentWeekStart = widget.today.startOfWeek(1);
    final earliest =
        earliestRelevantDay(widget.habit, widget.logs) ?? widget.today;
    final earliestWeekStart = earliest.startOfWeek(1);

    var totalWeeks =
        (currentWeekStart.differenceInDays(earliestWeekStart) ~/ 7) + 1;
    if (totalWeeks > widget.maxWeeks) totalWeeks = widget.maxWeeks;
    if (totalWeeks < 1) totalWeeks = 1;

    final firstWeekStart = currentWeekStart.addDays(-7 * (totalWeeks - 1));

    _step = step;
    _totalWeeks = totalWeeks;
    _firstWeekStart = firstWeekStart;
    _scheduleJumpToEnd(totalWeeks);

    final gridWidth = totalWeeks * step - widget.gap;
    final gridHeight = 7 * step;

    final grid = CustomPaint(
      size: Size(gridWidth, gridHeight),
      painter: _HeatmapPainter(
        habit: widget.habit,
        logs: widget.logs,
        today: widget.today,
        firstWeekStart: firstWeekStart,
        weeks: totalWeeks,
        cellSize: widget.cellSize,
        gap: widget.gap,
        accent: accent,
        brightness: theme.brightness,
        outlineColor: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );

    final scrollable = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: widget.onDayTap == null
          ? grid
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleTap(details.localPosition),
              child: grid,
            ),
    );

    if (!widget.showWeekdayLabels) return scrollable;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          height: gridHeight,
          child: Column(
            children: [
              for (final label in _weekdayLabels)
                SizedBox(
                  height: step,
                  child: Center(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: scrollable),
      ],
    );
  }

  void _scheduleJumpToEnd(int totalWeeks) {
    if (_lastWeekCount == totalWeeks) return;
    _lastWeekCount = totalWeeks;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  void _handleTap(Offset localPosition) {
    final onDayTap = widget.onDayTap;
    if (onDayTap == null) return;

    final week = localPosition.dx ~/ _step;
    final row = localPosition.dy ~/ _step;
    if (week < 0 || week >= _totalWeeks || row < 0 || row >= 7) return;

    final day = _firstWeekStart.addDays(week * 7 + row);
    if (day.isAfter(widget.today)) return;
    onDayTap(day);
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.habit,
    required this.logs,
    required this.today,
    required this.firstWeekStart,
    required this.weeks,
    required this.cellSize,
    required this.gap,
    required this.accent,
    required this.brightness,
    required this.outlineColor,
  });

  final Habit habit;
  final Map<LocalDay, HabitLog> logs;
  final LocalDay today;
  final LocalDay firstWeekStart;
  final int weeks;
  final double cellSize;
  final double gap;
  final Color accent;
  final Brightness brightness;
  final Color outlineColor;

  bool get _isDark => brightness == Brightness.dark;

  @override
  void paint(Canvas canvas, Size size) {
    final step = cellSize + gap;
    final radius = Radius.circular(cellSize * 0.28);
    final paint = Paint()..style = PaintingStyle.fill;
    final todayOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = outlineColor;

    final neutral = _isDark ? Colors.white : Colors.black;

    for (var week = 0; week < weeks; week++) {
      for (var row = 0; row < 7; row++) {
        final day = firstWeekStart.addDays(week * 7 + row);
        final log = logs[day];
        final intensity = heatmapIntensityFor(
          habit: habit,
          log: log,
          day: day,
          today: today,
        );

        final rect = Rect.fromLTWH(
          week * step,
          row * step,
          cellSize,
          cellSize,
        );
        final rounded = RRect.fromRectAndRadius(rect, radius);

        paint.color = _fillFor(intensity, neutral);
        canvas.drawRRect(rounded, paint);

        if (day == today) {
          canvas.drawRRect(rounded.deflate(0.8), todayOutline);
        }

        final note = log?.note;
        if (note != null && note.trim().isNotEmpty) {
          final dotColor = intensity == HeatmapIntensity.done ||
                  intensity == HeatmapIntensity.partial
              ? (_isDark ? Colors.black : Colors.white)
              : (_isDark ? Colors.white : Colors.black);
          canvas.drawCircle(
            Offset(rect.right - 3.2, rect.bottom - 3.2),
            1.35,
            Paint()..color = dotColor.withValues(alpha: 0.85),
          );
        }
      }
    }
  }

  Color _fillFor(HeatmapIntensity intensity, Color neutral) {
    return switch (intensity) {
      HeatmapIntensity.done => accent,
      HeatmapIntensity.partial =>
        accent.withValues(alpha: _isDark ? 0.45 : 0.40),
      HeatmapIntensity.skipped =>
        accent.withValues(alpha: _isDark ? 0.14 : 0.12),
      HeatmapIntensity.missed =>
        neutral.withValues(alpha: _isDark ? 0.11 : 0.08),
      HeatmapIntensity.empty =>
        neutral.withValues(alpha: _isDark ? 0.045 : 0.035),
    };
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.habit != habit ||
        oldDelegate.logs != logs ||
        oldDelegate.today != today ||
        oldDelegate.weeks != weeks ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.accent != accent ||
        oldDelegate.brightness != brightness;
  }
}

/// A compact colour key shown under the large heatmap.
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendItem(
          colour: accent,
          label: 'Done',
          textStyle: theme.textTheme.bodySmall,
        ),
        _LegendItem(
          colour: accent.withValues(alpha: isDark ? 0.45 : 0.40),
          label: 'Partial',
          textStyle: theme.textTheme.bodySmall,
        ),
        _LegendItem(
          colour: onSurface.withValues(alpha: isDark ? 0.11 : 0.08),
          label: 'Missed',
          textStyle: theme.textTheme.bodySmall,
        ),
        _LegendItem(
          colour: onSurface.withValues(alpha: isDark ? 0.045 : 0.035),
          label: 'Not due',
          textStyle: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.colour,
    required this.label,
    required this.textStyle,
  });

  final Color colour;
  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: textStyle),
      ],
    );
  }
}
