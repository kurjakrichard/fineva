import 'package:flutter/material.dart';

/// The icons a category can have, by the key stored in the database. Keys,
/// not code points: a renamed or removed Material icon can't break the
/// data, and the icons stay tree-shakable.
const Map<String, IconData> categoryIcons = {
  'work': Icons.work,
  'storefront': Icons.storefront,
  'trending_up': Icons.trending_up,
  'redeem': Icons.redeem,
  'savings': Icons.savings,
  'payments': Icons.payments,
  'login': Icons.login,
  'shopping_cart': Icons.shopping_cart,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'home': Icons.home,
  'bolt': Icons.bolt,
  'water_drop': Icons.water_drop,
  'wifi': Icons.wifi,
  'phone': Icons.phone_iphone,
  'directions_bus': Icons.directions_bus,
  'directions_car': Icons.directions_car,
  'local_gas_station': Icons.local_gas_station,
  'flight': Icons.flight,
  'local_hospital': Icons.local_hospital,
  'medication': Icons.medication,
  'fitness_center': Icons.fitness_center,
  'theaters': Icons.theaters,
  'music_note': Icons.music_note,
  'sports_esports': Icons.sports_esports,
  'pets': Icons.pets,
  'child_friendly': Icons.child_friendly,
  'school': Icons.school,
  'checkroom': Icons.checkroom,
  'card_giftcard': Icons.card_giftcard,
  'business_center': Icons.business_center,
  'account_balance': Icons.account_balance,
  'receipt_long': Icons.receipt_long,
  'inventory': Icons.inventory_2,
  'calculate': Icons.calculate,
  'computer': Icons.computer,
  'credit_card': Icons.credit_card,
  'health_and_safety': Icons.health_and_safety,
  'percent': Icons.percent,
  'block': Icons.block,
  'build': Icons.build,
  'eco': Icons.eco,
  'star': Icons.star,
  'label': Icons.label,
  'more_horiz': Icons.more_horiz,
};

/// The icon of [key]; for no or an unknown key one picked by [id], so it
/// stays the same.
IconData categoryIcon(String? key, int? id) =>
    categoryIcons[key] ??
    categoryIcons.values.elementAt((id ?? 0) % categoryIcons.length);
