import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/widget_service.dart';

final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService();
});
