import 'dart:async';

/// Debounces notification-schedule rebuilds triggered by data changes.
class NotificationCoordinator {
  NotificationCoordinator({this.debounce = const Duration(seconds: 2)});

  final Duration debounce;

  Timer? _timer;
  bool _running = false;

  /// Schedules [rebuild] after the debounce window.
  void schedule(Future<void> Function() rebuild) {
    _timer?.cancel();
    _timer = Timer(debounce, () async {
      if (_running) return;
      _running = true;
      try {
        await rebuild();
      } finally {
        _running = false;
      }
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
