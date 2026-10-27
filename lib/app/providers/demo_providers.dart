import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/demo_data_service.dart';
import 'database_provider.dart';

/// Debug-only helper that seeds/removes a three-year demo history.
final demoDataServiceProvider = Provider<DemoDataService>((ref) {
  return DemoDataService(ref.watch(appDatabaseProvider));
});
