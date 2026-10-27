import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/remote/auth_service.dart';
import '../../data/remote/cloud_runtime.dart';
import '../../data/sync/sync_controller.dart';
import '../../data/sync/sync_service.dart';
import 'database_provider.dart';

/// Overridden in `main()` with the initialized runtime. Defaults to local-only.
final cloudRuntimeProvider = Provider<CloudRuntime>((ref) {
  return const CloudRuntime(configured: false);
});

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(cloudRuntimeProvider).client;
  return client == null ? null : AuthService(client);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(cloudRuntimeProvider).client;
  if (client == null) return const Stream<AuthState>.empty();
  return client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final runtime = ref.watch(cloudRuntimeProvider);
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? runtime.client?.auth.currentUser;
});

/// Stable user id; the sync service only rebuilds when this changes.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final runtime = ref.watch(cloudRuntimeProvider);
  final client = runtime.client;
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return null;

  final service = SyncService(
    ref.watch(appDatabaseProvider),
    client,
    userId,
  );
  ref.onDispose(service.stopRealtime);
  return service;
});

final syncControllerProvider = Provider<SyncController>((ref) {
  final controller = SyncController();
  ref.onDispose(controller.dispose);
  return controller;
});
