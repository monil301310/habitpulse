import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/shell_providers.dart';
import '../../app/theme/app_colors.dart';
import '../habits/habit_detail_screen.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../settings/settings_screen.dart';

/// Adaptive app frame: bottom navigation on phones, a rail on tablets and
/// Windows, and a list/detail two-pane Today view when there is room.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String? _selectedHabitId;

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabProvider);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 720;

    final body = IndexedStack(
      index: index,
      children: [
        _TodayTab(
          selectedHabitId: _selectedHabitId,
          onSelectHabit: (id) => setState(() => _selectedHabitId = id),
        ),
        const InsightsScreen(embedded: true),
        const SettingsScreen(embedded: true),
      ],
    );

    if (!useRail) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: ref.read(shellTabProvider.notifier).select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      );
    }

    final extended = width >= 1180;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            extended: extended,
            minExtendedWidth: 190,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            onDestinationSelected: ref.read(shellTabProvider.notifier).select,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: BrandMark(size: 36),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today_rounded),
                label: Text('Today'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: Text('Insights'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.selectedHabitId,
    required this.onSelectHabit,
  });

  final String? selectedHabitId;
  final ValueChanged<String?> onSelectHabit;

  @override
  Widget build(BuildContext context) {
    final twoPane = MediaQuery.sizeOf(context).width >= 900;
    if (!twoPane) return const HomeScreen();

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: HomeScreen(
            selectedHabitId: selectedHabitId,
            onOpenHabit: (id) => onSelectHabit(id),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 6,
          child: AnimatedSwitcher(
            duration: _motion(context),
            child: selectedHabitId == null
                ? const _DetailPlaceholder(key: ValueKey('placeholder'))
                : HabitDetailScreen(
                    key: ValueKey(selectedHabitId),
                    habitId: selectedHabitId!,
                    embedded: true,
                    onClose: () => onSelectHabit(null),
                  ),
          ),
        ),
      ],
    );
  }
}

Duration _motion(BuildContext context) {
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return const Duration(milliseconds: 220);
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                color: AppColors.green,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Pick a habit',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a card on the left to see its heatmap, streaks and history '
              'here without leaving the list.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
