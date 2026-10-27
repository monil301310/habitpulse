import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The selected tab in [AppShell]: 0 Today, 1 Insights, 2 Settings.
class ShellTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    if (index < 0 || index > 2) return;
    state = index;
  }
}

final shellTabProvider = NotifierProvider<ShellTabController, int>(
  ShellTabController.new,
);
