import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'secure_local_storage.dart';

/// Holds the initialized Supabase client (or nothing in local-only mode).
class CloudRuntime {
  const CloudRuntime({required this.configured, this.client, this.error});

  final bool configured;
  final SupabaseClient? client;
  final String? error;

  bool get isAvailable => configured && client != null;

  User? get currentUser => client?.auth.currentUser;

  Stream<AuthState> get authChanges =>
      client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  static Future<CloudRuntime> initialize(SupabaseConfig config) async {
    if (!config.isConfigured) {
      return const CloudRuntime(configured: false);
    }

    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.anonKey,
        debug: kDebugMode,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(),
        ),
      );
      return CloudRuntime(configured: true, client: Supabase.instance.client);
    } on Object catch (error) {
      debugPrint('Supabase initialization failed: $error');
      return CloudRuntime(configured: true, error: '$error');
    }
  }
}
