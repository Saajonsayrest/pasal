import 'package:flutter/material.dart';

/// Categories store an icon as a Material Symbols name (`egg`). Flutter has no lookup by name,
/// so the names the pickers offer are listed here. Unknown names show a generic category icon.
/// The website offers the same list (web/src/routes/D8Categories.svelte).
const categoryIconNames = <String, IconData>{
  'category': Icons.category_rounded,
  'egg': Icons.egg_rounded,
  'rice_bowl': Icons.rice_bowl_rounded,
  'local_drink': Icons.local_drink_rounded,
  'cookie': Icons.cookie_rounded,
  'cleaning_services': Icons.cleaning_services_rounded,
  'spa': Icons.spa_rounded,
  'bakery_dining': Icons.bakery_dining_rounded,
  'set_meal': Icons.set_meal_rounded,
  'nutrition': Icons.eco_rounded,
  'icecream': Icons.icecream_rounded,
  'liquor': Icons.liquor_rounded,
  'medication': Icons.medication_rounded,
  'checkroom': Icons.checkroom_rounded,
  'toys': Icons.toys_rounded,
  'pets': Icons.pets_rounded,
  'home': Icons.home_rounded,
  'kitchen': Icons.kitchen_rounded,
  'hardware': Icons.hardware_rounded,
  'bolt': Icons.bolt_rounded,
  'school': Icons.school_rounded,
  'devices': Icons.devices_rounded,
  'restaurant': Icons.restaurant_rounded,
  'store': Icons.store_rounded,
};

IconData symbolIcon(String? name) => categoryIconNames[name] ?? Icons.category_rounded;

/// "#1f8a63" to a [Color], or null when it is not a valid colour.
Color? colorFromHex(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// A [Color] to "#rrggbb".
String hexFromColor(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
