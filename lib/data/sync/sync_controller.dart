import 'dart:async';

import 'package:flutter/foundation.dart';

import 'sync_service.dart';

/// Snapshot of the last sync pass, used by the Settings screen.
class SyncStatus {
  const SyncStatus({
    this.syncing = false,
    this.lastSyncedAt,
    this.error,
    this.pushed = 0,
    this.pulled = 0,
  });

  final bool syncing;
  final DateTime? lastSyncedAt;
  final String? error;
  final int pushed;
  final int pulled;
}

/// Owns the current [SyncService] and debounces sync runs.
class SyncController {
  final ValueNotifier<SyncStatus> status = ValueNotifier<SyncStatus>(
    const SyncStatus(),
  );

  SyncService? _service;
  Timer? _debounce;
  bool _busy = false;

  void bind(SyncService? service) {
    if (identical(service, _service)) return;
    _service?.stopRealtime();
    _service = service;
    service?.startRealtime(schedule);
    if (service != null) schedule();
  }

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<void> syncNow() async {
    final service = _service;
    if (service == null || _busy) return;

    _busy = true;
    status.value = SyncStatus(
      syncing: true,
      lastSyncedAt: status.value.lastSyncedAt,
    );

    final summary = await service.sync();
    status.value = SyncStatus(
      syncing: false,
      lastSyncedAt: summary.finishedAt,
      error: summary.error == null ? null : '${summary.error}',
      pushed: summary.pushed,
      pulled: summary.pulled,
    );
    _busy = false;
  }

  /// Clears the displayed status (for example after sign-out).
  void reset() {
    status.value = const SyncStatus();
  }

  void dispose() {
    _debounce?.cancel();
    _service?.stopRealtime();
    status.dispose();
  }
}
