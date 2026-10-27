import '../entities/app_settings.dart';

/// Reads and writes the single local settings row.
abstract interface class SettingsRepository {
  Stream<AppSettings> watchSettings();
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}
