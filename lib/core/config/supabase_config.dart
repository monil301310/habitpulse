import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase connection details loaded from the local `.env` file.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  final String url;
  final String anonKey;

  /// Cloud features are optional: without keys the app runs in local-only mode.
  bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  static Future<SupabaseConfig> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } on Object {
      // No .env bundled: stay in local-only mode.
    }
    return SupabaseConfig(
      url: dotenv.env['SUPABASE_URL']?.trim() ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '',
    );
  }
}
