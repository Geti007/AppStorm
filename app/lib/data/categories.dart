import 'package:flutter/material.dart';

import 'models.dart';

/// Category colours in light and dark mode (DESIGN.md §2). The first 7 are
/// the built-in categories; custom categories can use all 12.
const List<(Color, Color)> categoryColors = [
  (Color(0xFF4F46E5), Color(0xFFA5B4FC)),
  (Color(0xFFE8603F), Color(0xFFFF9A7E)),
  (Color(0xFF0284C7), Color(0xFF7DD3FC)),
  (Color(0xFFB7791F), Color(0xFFF6C453)),
  (Color(0xFFB4237A), Color(0xFFF49AC8)),
  (Color(0xFF4D7C0F), Color(0xFFA3E635)),
  (Color(0xFF64748B), Color(0xFFCBD5E1)),
  (Color(0xFF0891B2), Color(0xFF67E8F9)),
  (Color(0xFF7C3AED), Color(0xFFC4B5FD)),
  (Color(0xFFDC2626), Color(0xFFFCA5A5)),
  (Color(0xFF92400E), Color(0xFFE0B48A)),
  (Color(0xFF374151), Color(0xFF9CA3AF)),
];

const List<String> categoryColorNames = [
  'Indigo', 'Coral', 'Sky blue', 'Amber', 'Magenta', 'Lime green', //
  'Slate', 'Cyan', 'Violet', 'Red', 'Brown', 'Graphite',
];

/// Icons a category can use, by a stable key stored in the database.
const Map<String, IconData> categoryIcons = {
  'bed': Icons.bed_outlined,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe_outlined,
  'local_bar': Icons.local_bar_outlined,
  'directions_bus': Icons.directions_bus_outlined,
  'flight': Icons.flight,
  'train': Icons.train_outlined,
  'local_taxi': Icons.local_taxi_outlined,
  'directions_car': Icons.directions_car_outlined,
  'local_gas_station': Icons.local_gas_station_outlined,
  'local_activity': Icons.local_activity_outlined,
  'museum': Icons.museum_outlined,
  'beach_access': Icons.beach_access_outlined,
  'hiking': Icons.hiking,
  'downhill_skiing': Icons.downhill_skiing,
  'shopping_bag': Icons.shopping_bag_outlined,
  'local_grocery_store': Icons.local_grocery_store_outlined,
  'local_pharmacy': Icons.local_pharmacy_outlined,
  'card_giftcard': Icons.card_giftcard,
  'wifi': Icons.wifi,
  'local_laundry_service': Icons.local_laundry_service_outlined,
  'volunteer_activism': Icons.volunteer_activism_outlined,
  'confirmation_number': Icons.confirmation_number_outlined,
  'category': Icons.category_outlined,
};

class CategoryInfo {
  const CategoryInfo({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorIndex,
    required this.builtIn,
  });

  final String id;
  final String name;
  final String iconKey;
  final int colorIndex;
  final bool builtIn;

  IconData get icon => categoryIcons[iconKey] ?? Icons.category_outlined;

  Color color(Brightness b) {
    final pair = categoryColors[colorIndex % categoryColors.length];
    return b == Brightness.dark ? pair.$2 : pair.$1;
  }
}

const String otherCategoryId = 'other';

const List<CategoryInfo> builtInCategories = [
  CategoryInfo(
    id: 'accommodation',
    name: 'Accommodation',
    iconKey: 'bed',
    colorIndex: 0,
    builtIn: true,
  ),
  CategoryInfo(
    id: 'food',
    name: 'Food & drink',
    iconKey: 'restaurant',
    colorIndex: 1,
    builtIn: true,
  ),
  CategoryInfo(
    id: 'transport',
    name: 'Transport',
    iconKey: 'directions_bus',
    colorIndex: 2,
    builtIn: true,
  ),
  CategoryInfo(
    id: 'activities',
    name: 'Activities',
    iconKey: 'local_activity',
    colorIndex: 3,
    builtIn: true,
  ),
  CategoryInfo(
    id: 'shopping',
    name: 'Shopping',
    iconKey: 'shopping_bag',
    colorIndex: 4,
    builtIn: true,
  ),
  CategoryInfo(
    id: 'groceries',
    name: 'Groceries',
    iconKey: 'local_grocery_store',
    colorIndex: 5,
    builtIn: true,
  ),
  CategoryInfo(
    id: otherCategoryId,
    name: 'Other',
    iconKey: 'category',
    colorIndex: 6,
    builtIn: true,
  ),
];

CategoryInfo customCategoryInfo(CustomCategory c) => CategoryInfo(
  id: c.id,
  name: c.name,
  iconKey: c.iconKey,
  colorIndex: c.colorIndex,
  builtIn: false,
);
