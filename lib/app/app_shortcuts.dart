import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/habits/habit_form_screen.dart';
import 'notification_navigation.dart';
import 'providers/shell_providers.dart';

/// Desktop keyboard shortcuts: Ctrl+N, Ctrl+1/2/3, Ctrl+, and Esc.
class AppShortcuts extends ConsumerWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void tab(int index) => ref.read(shellTabProvider.notifier).select(index);

    void newHabit() {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const HabitFormScreen()),
      );
    }

    void escape() {
      final navigator = appNavigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      } else {
        tab(0);
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): newHabit,
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            tab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            tab(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            tab(2),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            tab(2),
        const SingleActivator(LogicalKeyboardKey.escape): escape,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
