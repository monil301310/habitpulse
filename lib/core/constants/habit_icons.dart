import 'package:flutter/material.dart';

/// The built-in icon set a habit can choose from.
abstract final class HabitIcons {
  static const Map<String, IconData> all = <String, IconData>{
    'bolt': Icons.bolt_rounded,
    'book': Icons.menu_book_rounded,
    'fitness': Icons.fitness_center_rounded,
    'run': Icons.directions_run_rounded,
    'water': Icons.water_drop_rounded,
    'food': Icons.restaurant_rounded,
    'bed': Icons.bedtime_rounded,
    'meditate': Icons.self_improvement_rounded,
    'code': Icons.code_rounded,
    'music': Icons.music_note_rounded,
    'clean': Icons.cleaning_services_rounded,
    'money': Icons.savings_rounded,
    'phone': Icons.phone_iphone_rounded,
    'no_smoke': Icons.smoke_free_rounded,
    'heart': Icons.favorite_rounded,
    'star': Icons.star_rounded,
  };

  static IconData resolve(String key) => all[key] ?? Icons.bolt_rounded;
}
