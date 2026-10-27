import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers/cloud_providers.dart';
import '../app/providers/habit_providers.dart';
import '../app/providers/log_providers.dart';
import '../app/providers/reminder_providers.dart';
import '../app/providers/settings_providers.dart';

/// Triggers a sync on start, after local changes, on reconnect and every
/// 15 minutes while the app is in the foreground.
class CloudSyncScope extends ConsumerStatefulWidget {
  const CloudSyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CloudSyncScope> createState() => _CloudSyncScopeState();
}

class _CloudSyncScopeState extends ConsumerState<CloudSyncScope> {
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _periodic;

  @override
  void initState() {
    super.initState();

    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) ref.read(syncControllerProvider).schedule();
    });

    _periodic = Timer.periodic(const Duration(minutes: 15), (_) {
      ref.read(syncControllerProvider).schedule();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(syncControllerProvider)
          .bind(ref.read(syncServiceProvider));
    });
  }

  @override
  void dispose() {
    _connectivity?.cancel();
    _periodic?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncServiceProvider, (previous, next) {
      ref.read(syncControllerProvider).bind(next);
    });
    ref.listen(habitsProvider, (_, _) => _schedule());
    ref.listen(remindersProvider, (_, _) => _schedule());
    ref.listen(allLogsProvider, (_, _) => _schedule());
    ref.listen(appSettingsProvider, (_, _) => _schedule());
    return widget.child;
  }

  void _schedule() => ref.read(syncControllerProvider).schedule();
}
